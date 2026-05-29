#!/usr/bin/env dart

/// PurpleOTel Release Script
///
/// Automates the full release pipeline:
///
///   dart run tool/release.dart                    # interactive (asks version)
///   dart run tool/release.dart -- patch           # auto-increment patch
///   dart run tool/release.dart -- minor           # auto-increment minor
///   dart run tool/release.dart -- major           # auto-increment major
///   dart run tool/release.dart -- version 1.2.0   # explicit version
///   dart run tool/release.dart -- version 1.2.0 --dry-run
///   dart run tool/release.dart -- version 1.2.0 --publish
///
/// Workflow:
///   1. Determine which packages changed since last tag
///   2. Bump versions (with melos)
///   3. Generate/update CHANGELOG.md for each changed package
///   4. Commit changes
///   5. Create git tags
///   6. Optionally publish to pub.dev

import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:git/git.dart';

Future<void> main(List<String> args) async {
  final parser = ReleaseArgs(args);

  if (parser.showHelp) {
    _printHelp();
    return;
  }

  final packages = await _findChangedPackages();
  if (packages.isEmpty) {
    _info('No packages with changes since last release. Nothing to do.');
    return;
  }

  _info('Changed packages: ${packages.map((p) => p.name).join(', ')}');

  // Step 1: Determine version
  final version = await parser.resolveVersion(packages);

  // Step 2: Bump versions with melos
  _info('Bumping versions to $version...');
  await _run('melos', [
    'version',
    version.toString(),
    '--yes',
    ...packages.map((p) => '--include-dependents=$p.name'),
  ]);

  // Step 3: Generate CHANGELOG for each package
  _info('Generating changelogs...');
  for (final pkg in packages) {
    await _generateChangelog(pkg, version);
  }

  // Step 4: Update dependent pubspecs (replace path with version)
  await _fixPubspecDependencies(packages, version);

  // Step 5: Commit
  if (!parser.dryRun) {
    _info('Committing changes...');
    await _run('git', ['add', '-A']);
    for (final pkg in packages) {
      await _run('git', [
        'commit',
        '-m',
        'chore(release): publish ${pkg.name} v$version',
      ]);
      await _run('git', ['tag', '${pkg.name}-v$version']);
    }
    await _run('git', ['push', '--follow-tags']);
  }

  // Step 6: Publish
  if (parser.publish) {
    _info('Publishing to pub.dev...');
    for (final pkg in packages) {
      await _publishPackage(pkg);
    }
    // Restore path dependencies for local development
    await _run('melos', ['bootstrap']);
  }

  _info('Done!');
}

Future<List<_PackageInfo>> _findChangedPackages() async {
  final result = await _runCapture('git', [
    'diff',
    '--name-only',
    'HEAD',
    '--',
    'packages/shared/',
  ]);

  final changedPaths = LineSplitter.split(result.stdout as String)
      .where((l) => l.isNotEmpty)
      .map((l) => l.split('/').take(2).join('/'))
      .toSet();

  final packages = <_PackageInfo>[];
  for (final dir in Directory('packages/shared').listSync()) {
    if (dir is! Directory) continue;
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (!pubspec.existsSync()) continue;
    final yaml = loadYaml(pubspec.readAsStringSync()) as YamlMap;
    packages.add(_PackageInfo(
      name: yaml['name'] as String,
      path: dir.path,
      currentVersion: yaml['version'] as String,
      changed: changedPaths.contains(dir.path.split(Platform.pathSeparator).take(2).join('/')),
    ));
  }
  return packages.where((p) => p.changed).toList();
}

Future<void> _generateChangelog(_PackageInfo pkg, Version version) async {
  final changelogFile = File('${pkg.path}/CHANGELOG.md');
  final lastTag = '${pkg.name}-v${pkg.currentVersion}';

  final commits = await _getCommitsSinceTag(lastTag);
  if (commits.isEmpty) return;

  final changes = _parseConventionalCommits(commits);
  final newEntry = _formatChangelogEntry(version.toString(), changes);

  // Prepend new entry to existing CHANGELOG
  if (changelogFile.existsSync()) {
    final existing = changelogFile.readAsStringSync();
    final headerEnd = existing.indexOf('\n## ');
    if (headerEnd > 0) {
      changelogFile.writeAsStringSync(
        '${existing.substring(0, headerEnd)}\n\n$newEntry\n${existing.substring(headerEnd)}',
      );
    } else {
      changelogFile.writeAsStringSync(newEntry);
    }
  } else {
    changelogFile.writeAsStringSync('# ${pkg.name}\n\n$newEntry');
  }
}

Future<List<String>> _getCommitsSinceTag(String tag) async {
  try {
    final result = await _runCapture('git', [
      'log',
      '$tag..HEAD',
      '--pretty=format:%s',
      '--',
      'packages/shared/',
    ]);
    return LineSplitter.split(result.stdout as String)
        .where((l) => l.isNotEmpty)
        .toList();
  } catch (_) {
    // Tag doesn't exist — get all commits
    final result = await _runCapture('git', [
      'log',
      '--pretty=format:%s',
      '--',
      'packages/shared/',
    ]);
    return LineSplitter.split(result.stdout as String)
        .where((l) => l.isNotEmpty)
        .toList();
  }
}

Map<String, List<String>> _parseConventionalCommits(List<String> commits) {
  final changes = <String, List<String>>{
    'Features': [],
    'Bug Fixes': [],
    'Documentation': [],
    'Performance': [],
    'Refactoring': [],
    'Chores': [],
  };

  for (final commit in commits) {
    final match = RegExp(r'^(feat|fix|docs|perf|refactor|chore)(?:\((\w+)\))?:\s*(.*)')
        .firstMatch(commit);
    if (match == null) continue;

    final type = match.group(1)!;
    final scope = match.group(2);
    final msg = '${match.group(3)}${scope != null ? ' ($scope)' : ''}';

    switch (type) {
      case 'feat':
        changes['Features']!.add(msg);
      case 'fix':
        changes['Bug Fixes']!.add(msg);
      case 'docs':
        changes['Documentation']!.add(msg);
      case 'perf':
        changes['Performance']!.add(msg);
      case 'refactor':
        changes['Refactoring']!.add(msg);
      case 'chore':
        changes['Chores']!.add(msg);
    }
  }
  return changes;
}

String _formatChangelogEntry(String version, Map<String, List<String>> changes) {
  final buf = StringBuffer();
  buf.writeln('## $version');
  buf.writeln();

  for (final entry in changes.entries) {
    if (entry.value.isEmpty) continue;
    buf.writeln('### ${entry.key}');
    buf.writeln();
    for (final item in entry.value) {
      buf.writeln('- $item');
    }
    buf.writeln();
  }
  return buf.toString();
}

Future<void> _fixPubspecDependencies(List<_PackageInfo> packages, Version version) async {
  for (final pkg in packages) {
    final pubspecFile = File('${pkg.path}/pubspec.yaml');
    var content = pubspecFile.readAsStringSync();

    for (final dep in packages) {
      if (dep.name == pkg.name) continue;
      content = content.replaceAll(
        RegExp('${dep.name}:\\s*\\n\\s*path:.*'),
        '${dep.name}: ^$version',
      );
    }

    pubspecFile.writeAsStringSync(content);
  }
}

Future<void> _publishPackage(_PackageInfo pkg) async {
  _info('Publishing ${pkg.name}...');
  await _run('dart', ['pub', 'publish', '--force'], workingDirectory: pkg.path);
}

Future<ProcessResult> _run(String executable, List<String> arguments,
    {String? workingDirectory}) async {
  final result = await Process.run(executable, arguments,
      workingDirectory: workingDirectory);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    throw ProcessException(executable, arguments, result.stderr.toString(), result.exitCode);
  }
  return result;
}

Future<ProcessResult> _runCapture(String executable, List<String> arguments) async {
  return Process.run(executable, arguments, runInShell: true);
}

void _info(String message) {
  stdout.writeln('\x1B[34m[release]\x1B[0m $message');
}

void _printHelp() {
  print('''
PurpleOTel Release Script

Usage: dart run tool/release.dart [options]

Options:
  --patch            Auto-increment patch version
  --minor            Auto-increment minor version
  --major            Auto-increment major version
  --version <v>      Use exact version (e.g., --version 1.2.0)
  --dry-run          Preview without committing or publishing
  --publish          Also publish to pub.dev after release
  --help             Show this help
'');
}

class ReleaseArgs {
  final List<String> _args;
  ReleaseArgs(this._args);

  bool get showHelp => _args.contains('--help');
  bool get dryRun => _args.contains('--dry-run');
  bool get publish => _args.contains('--publish');

  Future<Version> resolveVersion(List<_PackageInfo> packages) async {
    if (_args.contains('--version')) {
      final idx = _args.indexOf('--version');
      return Version.parse(_args[idx + 1]);
    }
    // Default: ask interactively or auto-detect
    final latest = packages
        .map((p) => Version.parse(p.currentVersion))
        .reduce((a, b) => a.compareTo(b) > 0 ? a : b);

    if (_args.contains('--major')) return latest.nextMajor;
    if (_args.contains('--minor')) return latest.nextMinor;
    if (_args.contains('--patch')) return latest.nextPatch;

    // Interactive
    stdout.write('Next version [${latest.nextMinor}]: ');
    final input = stdin.readLineSync();
    if (input == null || input.isEmpty) return latest.nextMinor;
    return Version.parse(input);
  }
}

class _PackageInfo {
  final String name;
  final String path;
  final String currentVersion;
  final bool changed;

  _PackageInfo({
    required this.name,
    required this.path,
    required this.currentVersion,
    required this.changed,
  });
}

class Version implements Comparable<Version> {
  final int major;
  final int minor;
  final int patch;
  final String? preRelease;

  Version(this.major, this.minor, this.patch, {this.preRelease});

  factory Version.parse(String v) {
    final parts = v.split('.');
    return Version(
      int.parse(parts[0]),
      parts.length > 1 ? int.parse(parts[1]) : 0,
      parts.length > 2 ? int.parse(parts[2]) : 0,
    );
  }

  Version get nextMajor => Version(major + 1, 0, 0);
  Version get nextMinor => Version(major, minor + 1, 0);
  Version get nextPatch => Version(major, minor, patch + 1);

  @override
  int compareTo(Version other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}
