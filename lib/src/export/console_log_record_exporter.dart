import 'package:purple_otel_api/purple_otel_api.dart';

/// A [LogRecordExporter] that writes log records to `stdout` for debugging.
///
/// Does not connect to any backend; output is printed via `print()`. Supports
/// two formats: human-readable ("pretty") and JSON-like structured output.
final class ConsoleLogRecordExporter implements LogRecordExporter {
  final bool _pretty;

  /// Creates a [ConsoleLogRecordExporter].
  ///
  /// [pretty] controls whether records are printed in a human-readable format
  /// (`true`, default) or as JSON-like maps (`false`).
  const ConsoleLogRecordExporter({bool pretty = true}) : _pretty = pretty;

  @override
  Future<ExportResult> export(List<LogRecord> items) async {
    for (final record in items) {
      if (_pretty) {
        _printPretty(record);
      } else {
        _printJson(record);
      }
    }
    return ExportResult.success();
  }

  void _printPretty(LogRecord record) {
    final sev = record.severityNumber.name.toUpperCase().padRight(5);
    final ts = record.observedTimestamp.toIso8601String();
    final body = _formatBody(record.body);
    final attrs = record.attributes.isNotEmpty ? ' ${record.attributes}' : '';
    print('[$sev] $ts $body$attrs');
  }

  void _printJson(LogRecord record) {
    final map = <String, Object?>{
      'severity': record.severityNumber.name,
      'timestamp': record.observedTimestamp.toIso8601String(),
      'body': _formatBody(record.body),
    };
    if (record.attributes.isNotEmpty) {
      map['attributes'] = record.attributes.toString();
    }
    print(map);
  }

  String _formatBody(AttributeValue body) {
    var result = '';
    body.map(
      string: (v) => result = v,
      int: (v) => result = '$v',
      double: (v) => result = '$v',
      bool: (v) => result = '$v',
      list: (v) => result = v.toString(),
      bytes: (v) => result = '<bytes ${v.length}B>',
    );
    return result;
  }

  @override
  Future<void> shutdown() async {}

  @override
  Future<void> forceFlush() async {}
}
