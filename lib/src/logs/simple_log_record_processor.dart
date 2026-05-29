import 'package:purple_otel_api/purple_otel_api.dart';

/// A [LogRecordProcessor] that exports each log record synchronously as soon as
/// it is emitted.
///
/// No batching or buffering — every [onEmit] call immediately delegates to the
/// wrapped [LogRecordExporter].
final class SimpleLogRecordProcessor implements LogRecordProcessor {
  final LogRecordExporter _exporter;

  /// Creates a [SimpleLogRecordProcessor] that exports through [exporter].
  SimpleLogRecordProcessor(this._exporter);

  @override
  void onEmit(Context context, LogRecord record) {
    _exporter.export([record]);
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    await _exporter.shutdown();
  }
}
