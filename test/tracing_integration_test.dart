import 'dart:async';

import 'package:purple_otel_sdk/purple_otel_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('ZoneContextStorage', () {
    test('current returns Context.root when no zone active', () {
      final storage = ZoneContextStorage();
      expect(storage.current, Context.root);
    });

    test('runWithContext stores context in zone', () {
      final storage = ZoneContextStorage();
      final key = ContextKey<String>('test');
      final ctx = Context.root.withValue(key, 'hello');

      ZoneContextStorage.runWithContext(ctx, () {
        expect(storage.current.get(key), 'hello');
      });
    });

    test('nested zones inherit parent context', () {
      final storage = ZoneContextStorage();
      final outerCtx = Context.root.withValue(ContextKey<String>('outer'), 'outer-value');

      ZoneContextStorage.runWithContext(outerCtx, () {
        runZoned(() {
          expect(storage.current.get(ContextKey<String>('outer')), 'outer-value');
        });
      });
    });
  });

  group('Distributed tracing', () {
    test('parent span -> child span via Zone context', () {
      final exporter = _CaptureSpanExporter();
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(exporter)],
      );
      final tracer = provider.get('test');

      final parent = tracer.startSpan('parent', kind: SpanKind.server);
      final parentCtx = Context.root.withValue(spanContextKey, parent);

      ZoneContextStorage.runWithContext(parentCtx, () {
        final child = tracer.startSpan('child', kind: SpanKind.client);

        expect(child.spanContext.traceId, parent.spanContext.traceId);
        expect(child.spanContext.spanId, isNot(parent.spanContext.spanId));

        child.end();
      });

      parent.end();
      expect(exporter.exported.length, 2);
    });

    test('log records inherit trace context from active span', () {
      final spanExporter = _CaptureSpanExporter();
      final tracerProvider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(spanExporter)],
      );
      final tracer = tracerProvider.get('test');

      final logExporter = _CaptureLogExporter();
      final logProvider = SDKLoggerProvider(
        resource: Resource.empty,
        processors: [SimpleLogRecordProcessor(logExporter)],
      );
      final logger = logProvider.get('test');

      final span = tracer.startSpan('traced-request');
      final spanCtx = Context.root.withValue(spanContextKey, span);

      ZoneContextStorage.runWithContext(spanCtx, () {
        logger.emit(LogRecord(
          timestamp: DateTime.now(),
          observedTimestamp: DateTime.now(),
          severityNumber: Severity.info,
          body: AttributeValue.string('log during trace'),
        ));
      });

      span.end();

      final logRecord = logExporter.exported.first;
      expect(logRecord.traceId, span.spanContext.traceId);
      expect(logRecord.spanId, span.spanContext.spanId);
    });
  });
}

final class _CaptureSpanExporter implements SpanExporter {
  final List<Span> exported = [];
  @override
  Future<ExportResult> export(List<Span> items) async {
    exported.addAll(items);
    return ExportResult.success();
  }
  @override
  Future<void> shutdown() async {}
  @override
  Future<void> forceFlush() async {}
}

final class _CaptureLogExporter implements LogRecordExporter {
  final List<LogRecord> exported = [];
  @override
  Future<ExportResult> export(List<LogRecord> items) async {
    exported.addAll(items);
    return ExportResult.success();
  }
  @override
  Future<void> shutdown() async {}
  @override
  Future<void> forceFlush() async {}
}
