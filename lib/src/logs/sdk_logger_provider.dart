import 'package:purple_otel_api/purple_otel_api.dart';
import 'sdk_logger.dart';

/// The flagship SDK implementation of [LoggerProvider].
///
/// Creates and caches [SDKLogger] instances keyed by instrumentation scope.
/// All loggers share the configured resource and log record processors.
final class SDKLoggerProvider implements LoggerProvider {
  final Resource _resource;
  final List<LogRecordProcessor> _processors;
  final Map<String, SDKLogger> _loggers = {};

  /// Creates an [SDKLoggerProvider].
  ///
  /// [resource] is the entity producing telemetry (service name, version, etc.).
  /// [processors] handle log record emission for all logger instances.
  SDKLoggerProvider({
    required Resource resource,
    required List<LogRecordProcessor> processors,
  })  : _resource = resource,
        _processors = List.unmodifiable(processors);

  /// The resource describing the entity producing telemetry.
  Resource get resource => _resource;

  /// Returns or creates a cached [SDKLogger] for the given scope.
  ///
  /// [name] identifies the instrumentation library. [version] and [schemaUrl]
  /// are optional scope attributes.
  @override
  SDKLogger get(String name, {String? version, String? schemaUrl}) {
    final key = '${name}\x00${version ?? ''}\x00${schemaUrl ?? ''}';
    return _loggers.putIfAbsent(
      key,
      () => SDKLogger(
        name: name,
        version: version,
        schemaUrl: schemaUrl,
        processors: _processors,
      ),
    );
  }

  /// Forces all registered [LogRecordProcessor] instances to flush pending records.
  @override
  Future<void> forceFlush() async {
    await Future.wait(_processors.map((p) => p.forceFlush()));
  }

  /// Shuts down all processors and clears the logger cache.
  @override
  Future<void> shutdown() async {
    _loggers.clear();
    await Future.wait(_processors.map((p) => p.shutdown()));
  }
}
