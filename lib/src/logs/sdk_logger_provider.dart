import 'package:purple_otel_api/purple_otel_api.dart';
import 'sdk_logger.dart';

final class SDKLoggerProvider implements LoggerProvider {
  final Resource _resource;
  final List<LogRecordProcessor> _processors;
  final Map<String, SDKLogger> _loggers = {};

  SDKLoggerProvider({
    required Resource resource,
    required List<LogRecordProcessor> processors,
  })  : _resource = resource,
        _processors = List.unmodifiable(processors);

  Resource get resource => _resource;

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

  @override
  Future<void> forceFlush() async {
    await Future.wait(_processors.map((p) => p.forceFlush()));
  }

  @override
  Future<void> shutdown() async {
    _loggers.clear();
    await Future.wait(_processors.map((p) => p.shutdown()));
  }
}
