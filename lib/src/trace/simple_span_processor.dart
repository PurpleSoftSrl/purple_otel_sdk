import 'package:purple_otel_api/purple_otel_api.dart';

/// A [SpanProcessor] that exports each span synchronously as soon as it ends.
///
/// No batching or buffering is performed — every call to [onEnd] immediately
/// delegates to the wrapped [SpanExporter]. This simplifies debugging and
/// testing but may cause higher export latency in production.
final class SimpleSpanProcessor implements SpanProcessor {
  final SpanExporter _exporter;

  /// Creates a [SimpleSpanProcessor] that exports spans through [exporter].
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
