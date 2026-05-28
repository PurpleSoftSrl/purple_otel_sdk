import 'package:purple_otel_api/purple_otel_api.dart';

final class SimpleLogRecordProcessor implements LogRecordProcessor {
  final LogRecordExporter _exporter;

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
