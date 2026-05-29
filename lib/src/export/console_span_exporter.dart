import 'package:purple_otel_api/purple_otel_api.dart';

import '../trace/sdk_span.dart';

/// A [SpanExporter] that writes span data to `stdout` for debugging.
///
/// Does not connect to any backend; output is printed via `print()`. Supports
/// two formats: human-readable ("pretty") and JSON-like structured output.
final class ConsoleSpanExporter implements SpanExporter {
  final bool _pretty;

  /// Creates a [ConsoleSpanExporter].
  ///
  /// [pretty] controls whether spans are printed in a human-readable format
  /// (`true`, default) or as JSON-like maps (`false`).
  const ConsoleSpanExporter({bool pretty = true}) : _pretty = pretty;

  @override
  Future<ExportResult> export(List<Span> items) async {
    for (final span in items) {
      if (_pretty) {
        _printPretty(span);
      } else {
        _printJson(span);
      }
    }
    return ExportResult.success();
  }

  void _printPretty(Span span) {
    final ctx = span.spanContext;
    final sdkSpan = span is SDKSpan ? span : null;
    final name = sdkSpan?.name ?? 'unknown';
    final kind = sdkSpan?.kind.name ?? 'internal';
    final duration = sdkSpan?.endTime != null
        ? '${sdkSpan!.endTime!.difference(sdkSpan.startTime)}'
        : 'ongoing';
    final attrs = sdkSpan?.attributes ?? {};
    final events = sdkSpan?.events ?? [];
    final status = sdkSpan?.status.code.name ?? 'unset';

    print('[SPAN] $name kind=$kind status=$status duration=$duration');
    print(
        '  trace=${ctx.traceId.toShortString()} span=${ctx.spanId.toShortString()}');
    if (attrs.isNotEmpty) {
      print('  attrs: $attrs');
    }
    for (final event in events) {
      print('  event: ${event.name} @ ${event.timestamp}');
    }
  }

  void _printJson(Span span) {
    final ctx = span.spanContext;
    final sdkSpan = span is SDKSpan ? span : null;
    print({
      'name': sdkSpan?.name ?? 'unknown',
      'traceId': ctx.traceId.toString(),
      'spanId': ctx.spanId.toString(),
      'kind': sdkSpan?.kind.name,
      'status': sdkSpan?.status.code.name,
    });
  }

  @override
  Future<void> shutdown() async {}

  @override
  Future<void> forceFlush() async {}
}
