import 'package:purple_otel_api/purple_otel_api.dart';

final class SimpleSpanProcessor implements SpanProcessor {
  final SpanExporter _exporter;

  SimpleSpanProcessor(this._exporter);

  @override
  bool get isStartRequired => false;

  @override
  bool get isEndRequired => true;

  @override
  void onStart(Context context, Span span) {}

  @override
  void onEnd(Span span) {
    _exporter.export([span]);
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    await _exporter.shutdown();
  }
}
