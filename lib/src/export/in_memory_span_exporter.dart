import 'package:purple_otel_api/purple_otel_api.dart';

/// A [SpanExporter] that retains exported spans in memory for testing.
///
/// Exported spans are appended to [spans]. The exporter never returns an error.
/// Call [clear] to reset accumulated spans.
final class InMemorySpanExporter implements SpanExporter {
  /// The list of all spans that have been exported.
  final List<Span> spans = [];

  /// Whether shutdown has been called.
  bool closed = false;

  @override
  Future<ExportResult> export(List<Span> items) async {
    spans.addAll(items);
    return ExportResult.success();
  }

  @override
  Future<void> shutdown() async {
    closed = true;
  }

  @override
  Future<void> forceFlush() async {}

  /// Clears all accumulated spans.
  void clear() => spans.clear();
}
