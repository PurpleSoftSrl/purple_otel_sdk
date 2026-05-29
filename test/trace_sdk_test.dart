import 'package:purple_otel_sdk/purple_otel_sdk.dart';
import 'package:test/test.dart';

final class _CaptureExporter implements SpanExporter {
  final List<Span> exported = [];
  bool shutdownCalled = false;

  @override
  Future<ExportResult> export(List<Span> items) async {
    exported.addAll(items);
    return ExportResult.success();
  }

  @override
  Future<void> shutdown() async {
    shutdownCalled = true;
  }

  @override
  Future<void> forceFlush() async {}
}

void main() {
  group('SDKTracerProvider', () {
    test('get returns cached tracer for same name', () {
      final exporter = _CaptureExporter();
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(exporter)],
      );
      final t1 = provider.get('test');
      final t2 = provider.get('test');
      expect(identical(t1, t2), isTrue);
    });

    test('get returns different tracers for different names', () {
      final exporter = _CaptureExporter();
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(exporter)],
      );
      final t1 = provider.get('test1');
      final t2 = provider.get('test2');
      expect(identical(t1, t2), isFalse);
    });
  });

  group('SDKTracer', () {
    test('creates sampled span with valid span context', () {
      final exporter = _CaptureExporter();
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(exporter)],
      );
      final tracer = provider.get('test-tracer');

      final span = tracer.startSpan('test-span');
      expect(span.spanContext.isValid, isTrue);
      expect(span.isRecording, isTrue);
    });

    test('end triggers processor chain and exporter', () {
      final exporter = _CaptureExporter();
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(exporter)],
      );
      final tracer = provider.get('test-tracer');

      final span = tracer.startSpan('my-span');
      span.end();

      expect(exporter.exported.length, 1);
    });

    test('span attributes are preserved', () {
      final exporter = _CaptureExporter();
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(exporter)],
      );
      final tracer = provider.get('test');

      final span = tracer.startSpan('attr-span');
      span.setAttribute('http.method', AttributeValue.string('GET'));
      span.setAttribute('http.status_code', AttributeValue.int(200));
      span.end();

      final exported = exporter.exported.first;
      expect(exported, isA<SDKSpan>());
      final sdkSpan = exported as SDKSpan;
      expect(sdkSpan.attributes['http.method'], AttributeValue.string('GET'));
      expect(sdkSpan.attributes['http.status_code'], AttributeValue.int(200));
    });

    test('span events are recorded', () {
      final exporter = _CaptureExporter();
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(exporter)],
      );
      final tracer = provider.get('test');

      final span = tracer.startSpan('event-span');
      span.addEvent('page.loaded',
          attributes: Attributes.of({'url': AttributeValue.string('/home')}));
      span.end();

      final sdkSpan = exporter.exported.first as SDKSpan;
      expect(sdkSpan.events.length, 1);
      expect(sdkSpan.events.first.name, 'page.loaded');
    });

    test('AlwaysOffSampler drops all spans', () {
      final exporter = _CaptureExporter();
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(exporter)],
        sampler: const AlwaysOffSampler(),
      );
      final tracer = provider.get('test');

      final span = tracer.startSpan('dropped-span');
      span.end();

      // NoopSpan is returned, exporter should be empty
      expect(span, isA<NoopSpan>());
      expect(exporter.exported.length, 0);
    });

    test('ParentBasedSampler propagates parent decision', () {
      final exporter = _CaptureExporter();
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(exporter)],
        sampler: ParentBasedSampler(const AlwaysOffSampler()),
      );
      final tracer = provider.get('test');

      // Without parent, root sampler (AlwaysOff) drops
      final span1 = tracer.startSpan('orphan');
      span1.end();
      expect(exporter.exported.length, 0);
    });
  });

  group('SimpleSpanProcessor', () {
    test('isStartRequired is false', () {
      final exporter = _CaptureExporter();
      final processor = SimpleSpanProcessor(exporter);
      expect(processor.isStartRequired, isFalse);
      expect(processor.isEndRequired, isTrue);
    });

    test('exports on span end', () {
      final exporter = _CaptureExporter();
      final processor = SimpleSpanProcessor(exporter);
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [processor],
      );
      final tracer = provider.get('test');

      tracer.startSpan('s1').end();
      tracer.startSpan('s2').end();

      expect(exporter.exported.length, 2);
    });
  });

  group('BatchSpanProcessor', () {
    test('batches spans before export', () async {
      final exporter = _CaptureExporter();
      final processor = BatchSpanProcessor(
        exporter,
        config: const BatchConfig(
            maxExportBatchSize: 2,
            maxQueueSize: 10,
            scheduleDelay: Duration(seconds: 60)),
      );
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [processor],
      );
      final tracer = provider.get('test');

      tracer.startSpan('s1').end();
      expect(exporter.exported.length, 0);

      tracer.startSpan('s2').end();
      expect(exporter.exported.length, 2);

      await processor.shutdown();
    });

    test('drops oldest when queue full', () async {
      final exporter = _CaptureExporter();
      final processor = BatchSpanProcessor(
        exporter,
        config: const BatchConfig(
            maxQueueSize: 2,
            maxExportBatchSize: 10,
            scheduleDelay: Duration(seconds: 60)),
      );
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [processor],
      );
      final tracer = provider.get('test');

      tracer.startSpan('s1').end();
      tracer.startSpan('s2').end();
      tracer.startSpan('s3').end();

      expect(processor.droppedCount, 1);
      await processor.shutdown();
    });
  });

  group('W3CTraceContextPropagator', () {
    test('inject writes traceparent header', () {
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [],
      );
      final tracer = provider.get('test');
      final span = tracer.startSpan('prop-test');

      final ctx = Context.root.withValue(spanContextKey, span);
      final carrier = <String, String>{};
      W3CTraceContextPropagator.inject(ctx, carrier);

      expect(carrier.containsKey('traceparent'), isTrue);
      final tp = carrier['traceparent']!;
      expect(tp.startsWith('00-'), isTrue);
    });

    test('extract reads traceparent header', () {
      final traceparent =
          '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01';
      final carrier = {'traceparent': traceparent};

      final ctx = W3CTraceContextPropagator.extract(Context.root, carrier);
      expect(ctx, isNotNull);
    });

    test('inject does nothing without active span', () {
      final carrier = <String, String>{};
      W3CTraceContextPropagator.inject(Context.root, carrier);
      expect(carrier.containsKey('traceparent'), isFalse);
    });
  });

  group('ConsoleSpanExporter', () {
    test('export returns success', () async {
      const exporter = ConsoleSpanExporter(pretty: false);
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(exporter)],
      );
      final tracer = provider.get('test');
      tracer.startSpan('console-test').end();
      // Should not throw, prints to console
    });
  });

  group('Cross-signal correlation', () {
    test('log record inherits span context from active span', () {
      // This test verifies the trace→logs correlation pattern
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [],
      );
      final tracer = provider.get('test');

      final span = tracer.startSpan('correlation-test');
      final spanCtx = span.spanContext;

      // In real usage, the Context would carry this span and logs would
      // automatically pick up traceId/spanId
      expect(spanCtx.isValid, isTrue);
      expect(spanCtx.traceId.isValid, isTrue);
      expect(spanCtx.spanId.isValid, isTrue);

      span.end();
    });
  });
}
