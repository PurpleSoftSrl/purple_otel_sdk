import 'package:purple_otel_api/purple_otel_api.dart';

final class InMemorySpanExporter implements SpanExporter {
  final List<Span> spans = [];
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

  void clear() => spans.clear();
}
