#!/usr/bin/env dart

/// CHANGELOG Generator
///
/// Reads conventional commits since the last git tag and generates
/// a CHANGELOG.md section with categorized entries.
///
/// Usage:
///   dart run tool/changelog.dart                     # all packages
///   dart run tool/changelog.dart --package purple_otel_sdk

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final pkgName = args.contains('--package') ? args[args.indexOf('--package') + 1] : null;

  final packages = pkgName != null
      ? [pkgName]
      : Directory('packages/shared').listSync().whereType<Directory>().map((d) {
          final parts = d.path.split(Platform.pathSeparator);
          return parts.last;
        }).toList();

  for (final pkg in packages) {
    final path = 'packages/shared/$pkg';
    if (!Directory(path).existsSync()) continue;

    final pubspec = File('$path/pubspec.yaml');
    if (!pubspec.existsSync()) continue;

    final tag = await _findLastTag(pkg);
    final commits = await _getCommits(tag, path);

    if (commits.isEmpty) {
      print('[$pkg] No commits since $tag');
      continue;
    }

    final changelog = _buildChangelog(commits, tag);
    print('[$pkg]');
    print(changelog);
    print('');
    print('--- Paste above section into $path/CHANGELOG.md ---');
  }
}

Future<String> _findLastTag(String pkg) async {
  final result = await Process.run('git', ['tag', '--sort=-v:refname'], runInShell: true);
  final tags = LineSplitter.split(result.stdout as String).where((t) => t.contains(pkg)).toList();
  return tags.isNotEmpty ? tags.first : 'initial';
}

Future<List<Map<String, String>>> _getCommits(String sinceTag, String path) async {
  final result = await Process.run('git', [
    'log',
    '--pretty=format:%s|||%h',
    '$sinceTag..HEAD',
    '--',
    path,
  ], runInShell: true);

  return LineSplitter.split(result.stdout as String)
      .where((l) => l.isNotEmpty && !l.startsWith('chore(release):'))
      .map((l) {
    final parts = l.split('|||');
    return {'message': parts[0], 'hash': parts.length > 1 ? parts[1] : 'unknown'};
  }).toList();
}

String _buildChangelog(List<Map<String, String>> commits, String sinceTag) {
  final buf = StringBuffer();
  buf.writeln('Changes since $sinceTag:');
  buf.writeln();

  final categories = _categorize(commits);

  for (final cat in categories.entries) {
    if (cat.value.isEmpty) continue;
    buf.writeln('### ${cat.key}');
    for (final c in cat.value) {
      buf.writeln('- ${c['cleanMsg']} (${c['hash']})');
    }
    buf.writeln();
  }

  return buf.toString();
}

Map<String, List<Map<String, String>>> _categorize(List<Map<String, String>> commits) {
  final cats = <String, List<Map<String, String>>>{
    'Features': [],
    'Bug Fixes': [],
    'Documentation': [],
    'Performance': [],
    'Refactoring': [],
    'Chores': [],
  };

  for (final c in commits) {
    final match = RegExp(r'^(feat|fix|docs|perf|refactor|chore)(?:\((\w+)\))?:\s*(.*)')
        .firstMatch(c['message']!);
    if (match == null) continue;

    final type = match.group(1)!;
    final scope = match.group(2);
    final msg = match.group(3)!;

    final entry = {
      'hash': c['hash']!,
      'cleanMsg': scope != null ? '$msg ($scope)' : msg,
    };

    switch (type) {
      case 'feat':
        cats['Features']!.add(entry);
      case 'fix':
        cats['Bug Fixes']!.add(entry);
      case 'docs':
        cats['Documentation']!.add(entry);
      case 'perf':
        cats['Performance']!.add(entry);
      case 'refactor':
        cats['Refactoring']!.add(entry);
      case 'chore':
        cats['Chores']!.add(entry);
    }
  }

  return cats;
}
