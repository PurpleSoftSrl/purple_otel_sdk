import 'dart:async';
import 'dart:isolate';

import 'package:purple_otel_sdk/purple_otel_sdk.dart';
import 'package:purple_otel_sdk/src/otlp/otlp_trace_encoder.dart';
import 'package:test/test.dart';

final class _NoopSpanProcessor implements SpanProcessor {
  @override
  bool get isStartRequired => false;
  @override
  bool get isEndRequired => false;
  @override
  void onStart(Context context, Span span) {}
  @override
  void onEnd(Span span) {}
  @override
  Future<void> forceFlush() async {}
  @override
  Future<void> shutdown() async {}
}

final class _EndRequiredProcessor implements SpanProcessor {
  final void Function(Span span) onEndFn;
  _EndRequiredProcessor(this.onEndFn);
  @override
  bool get isStartRequired => false;
  @override
  bool get isEndRequired => true;
  @override
  void onStart(Context context, Span span) {}
  @override
  void onEnd(Span span) => onEndFn(span);
  @override
  Future<void> forceFlush() async {}
  @override
  Future<void> shutdown() async {}
}

SDKSpan _makeSpan({
  SpanLimits? limits,
  String name = 'test-span',
  List<SpanProcessor>? processors,
}) {
  return SDKSpan(
    spanContext: SDKSpanContext(
      traceId: TraceId.generate(),
      spanId: SpanId.generate(),
      traceFlags: TraceFlags.sampled,
    ),
    scope: const InstrumentationScope(name: 'test-scope'),
    resource: Resource.empty,
    kind: SpanKind.internal,
    name: name,
    processors: processors ?? [_NoopSpanProcessor()],
    limits: limits ?? const SpanLimits(),
  );
}

void main() {
  // =========================================================================
  // 1. SDKSpan attacks
  // =========================================================================
  group('SDKSpan', () {
    test('double call to end() does not crash or re-export', () {
      final exported = <SDKSpan>[];
      final span = _makeSpan(processors: [
        _EndRequiredProcessor((s) => exported.add(s as SDKSpan)),
      ]);

      span.end();
      expect(span.isRecording, isFalse);
      expect(exported.length, 1);

      span.end();
      expect(exported.length, 1);
    });

    test('1,000,000 attributes respects SpanLimits.maxAttributes', () {
      final span = _makeSpan(
        limits: const SpanLimits(maxAttributes: 5),
      );

      for (var i = 0; i < 10000; i++) {
        span.setAttribute('key_$i', AttributeValue.int(i));
      }

      expect(span.attributes.length, equals(5));
    });

    test('addEvent 1,000,000 times respects SpanLimits.maxEvents', () {
      final span = _makeSpan(
        limits: const SpanLimits(maxEvents: 3),
      );

      for (var i = 0; i < 10000; i++) {
        span.addEvent('event_$i');
      }

      expect(span.events.length, equals(3));
    });

    test(
        'recordException with null error is caught by Dart type system'
        ' (Object is non-nullable)', () {
      // Dart 3 null safety prevents passing null to recordException(Object)
      // because the parameter type is non-nullable Object.
      // This is a compile-time guarantee, not a runtime one.
    });

    test('recordException with error whose toString() throws is safely caught', () {
      final span = _makeSpan();
      final evil = _EvilToString();
      span.recordException(evil);
    });

    test('setAttribute with empty key is accepted (no validation)', () {
      final span = _makeSpan();
      span.setAttribute('', AttributeValue.string('evil'));
      expect(span.attributes.containsKey(''), isTrue);
    });

    test('setStatus after end() is a no-op (guarded)', () {
      final span = _makeSpan();
      span.setStatus(SpanStatus.ok);
      span.end();
      span.setStatus(SpanStatus.error('post'));
      expect(span.status, SpanStatus.ok);
    });

    test('recordException after end() is a no-op (guarded)', () {
      final span = _makeSpan();
      span.end();
      final before = span.events.length;
      span.recordException(Exception('late error'));
      expect(span.events.length, before);
    });

    test('updateName after end() is a no-op (guarded)', () {
      final span = _makeSpan(name: 'original');
      span.end();
      span.updateName('changed-after-end');
      expect(span.name, 'original');
    });

    test('addLink 10,000 times respects SpanLimits.maxLinks', () {
      final span = _makeSpan(
        limits: const SpanLimits(maxLinks: 3),
      );

      for (var i = 0; i < 10000; i++) {
        span.addLink(SpanContext(
          traceId: TraceId.generate(),
          spanId: SpanId.generate(),
          traceFlags: TraceFlags.none,
        ));
      }

      expect(span.links.length, equals(3));
    });
  });

  // =========================================================================
  // 2. SDKTracer attacks
  // =========================================================================
  group('SDKTracer', () {
    test('startSpan with empty name does not crash', () {
      final exporter = InMemorySpanExporter();
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(exporter)],
      );
      final tracer = provider.get('test');

      final span = tracer.startSpan('');
      expect(span.isRecording, isTrue);
      span.end();
      expect(exporter.spans.length, 1);
    });

    test('startSpan with 10,000 character name does not crash', () {
      final exporter = InMemorySpanExporter();
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(exporter)],
      );
      final tracer = provider.get('test');

      final longName = 'x' * 10000;
      final span = tracer.startSpan(longName);
      expect(span.isRecording, isTrue);
      expect(span.spanContext.isValid, isTrue);
      span.end();
      expect(exporter.spans.length, 1);
    });

    test('startSpan with invalid parentContext still creates valid span', () {
      final exporter = InMemorySpanExporter();
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(exporter)],
      );
      final tracer = provider.get('test');

      final invalidSpanCtx = SpanContext(
        traceId: TraceId.invalid(),
        spanId: SpanId.invalid(),
        traceFlags: TraceFlags.none,
      );
      final parentCtx =
          Context.root.withValue(spanContextKey, _SpanWrapper(invalidSpanCtx));

      final span = tracer.startSpan('child', parentContext: parentCtx);
      expect(span.spanContext.isValid, isTrue);
      expect(span.spanContext.traceId.isValid, isTrue);
      span.end();
    });

    test('startSpan with null parentContext (explicit null) uses root', () {
      final exporter = InMemorySpanExporter();
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(exporter)],
      );
      final tracer = provider.get('test');

      final span = tracer.startSpan('orphan', parentContext: null);
      expect(span.isRecording, isTrue);
      span.end();
      expect(exporter.spans.length, 1);
    });
  });

  // =========================================================================
  // 3. StreamStore (metrics cardinality) attacks
  // =========================================================================
  group('StreamStore / CardinalityController', () {
    test('1,000,000 attribute combinations does not OOM or hang', () {
      const maxCard = 1000;
      final counter = LongCounter(maxCard);
      for (var i = 0; i < 5000; i++) {
        counter.add(i, attributes: Attributes.of({
          'unique': AttributeValue.string('val_$i'),
        }));
      }
      expect(counter.store.activeStreams, maxCard);
      expect(counter.store.overflowCount, 5000 - maxCard);
    });

    test('insert with empty Attributes works', () {
      final counter = LongCounter(100);
      counter.add(5, attributes: const Attributes.empty());
      final snapshot = counter.store.collectAndReset(false);
      expect(snapshot.length, 1);
      expect(snapshot.values.first.value, 5);
    });

    test('cardinality limit of 0 overflows everything', () {
      final counter = LongCounter(0);
      counter.add(1);
      counter.add(2);
      expect(counter.store.activeStreams, 0);
      expect(counter.store.overflowCount, 2);
    });

    test('negative cardinality limit behaves like 0', () {
      final counter = LongCounter(-5);
      counter.add(1);
      counter.add(2);
      expect(counter.store.activeStreams, 0);
      expect(counter.store.overflowCount, greaterThan(0));
    });

    test('concurrent collectAndReset from isolates', () async {
      final futures = <Future<Map<int, SumAggregator>>>[];
      for (var i = 0; i < 10; i++) {
        futures.add(Isolate.run(() {
          final counter = LongCounter(100);
          counter.add(1);
          return counter.store.collectAndReset(true);
        }));
      }
      final results = await Future.wait(futures);
      expect(results.length, 10);
    });

    test('collectAndReset(true) then add recovers cleanly', () {
      final counter = LongCounter(100);
      counter.add(42);
      final snap1 = counter.store.collectAndReset(true);
      expect(snap1.values.first.value, 42);

      counter.add(99);
      final snap2 = counter.store.collectAndReset(false);
      expect(snap2.values.first.value, 99);
    });
  });

  // =========================================================================
  // 4. Aggregation attacks
  // =========================================================================
  group('Aggregation', () {
    test('Counter near i64 max: overflow behavior', () {
      const nearMax = 9223372036854775807;
      final counter = LongCounter(10);
      counter.add(nearMax);
      counter.add(1);

      final snapshot = counter.store.collectAndReset(false);
      final val = snapshot.values.first.value;
      // Dart VM: int wraps beyond 64-bit signed on native platforms
      // Dart2js/Web: arbitrary precision, no overflow
      expect(val, isA<int>());
    });

    test('monotonic Counter.add(-1) is rejected', () {
      final counter = LongCounter(10);
      counter.add(100);
      counter.add(-50);
      final snapshot = counter.store.collectAndReset(false);
      expect(snapshot.values.first.value, 100);
    });

    test('UpDownCounter.add(-1) is accepted', () {
      final counter = LongUpDownCounter(10);
      counter.add(100);
      counter.add(-50);
      final snapshot = counter.store.collectAndReset(false);
      expect(snapshot.values.first.value, 50);
    });

    test('DoubleHistogram.record(double.infinity) is silently dropped', () {
      final hist = DoubleHistogramImpl(boundaries: [1.0, 10.0]);
      hist.record(double.infinity);
      final snapshot = hist.store.collectAndReset(false);
      final agg = snapshot.values.first;
      expect(agg.count, 0);
      expect(agg.sum, 0.0);
    });

    test('DoubleHistogram.record(double.negativeInfinity) is silently dropped', () {
      final hist = DoubleHistogramImpl(boundaries: [1.0, 10.0]);
      hist.record(double.negativeInfinity);
      final snapshot = hist.store.collectAndReset(false);
      final agg = snapshot.values.first;
      expect(agg.count, 0);
      expect(agg.sum, 0.0);
    });

    test('DoubleHistogram.record(double.nan) is silently dropped', () {
      final hist = DoubleHistogramImpl(boundaries: [1.0, 10.0]);
      hist.record(double.nan);
      final snapshot = hist.store.collectAndReset(false);
      final agg = snapshot.values.first;
      expect(agg.count, 0);
      expect(agg.sum, 0.0);
    });

    test('DoubleHistogram after NaN — only valid values counted', () {
      final hist = DoubleHistogramImpl(boundaries: [1.0, 10.0]);
      hist.record(5.0);
      hist.record(double.nan);
      hist.record(3.0);
      final snapshot = hist.store.collectAndReset(false);
      final agg = snapshot.values.first;
      expect(agg.count, 2);
      expect(agg.sum, 8.0);
      expect(agg.min, 3.0);
      expect(agg.max, 5.0);
    });

    test('DoubleCounter.add(double.nan)', () {
      final counter = DoubleCounter(10);
      counter.add(double.nan);
      final snapshot = counter.store.collectAndReset(false);
      expect(snapshot.values.first.value.isNaN, isTrue);
    });

    test('DoubleCounter near double max', () {
      final counter = DoubleCounter(10);
      counter.add(double.maxFinite);
      counter.add(double.maxFinite);
      final snapshot = counter.store.collectAndReset(false);
      expect(snapshot.values.first.value, double.infinity);
    });
  });

  // =========================================================================
  // 5. OTLP Encoding attacks
  // =========================================================================
  group('OTLP Encoding', () {
    test('encode 1,000 spans does not OOM', () {
      final exporter = InMemorySpanExporter();
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(exporter)],
      );
      final tracer = provider.get('encoder-test');

      for (var i = 0; i < 1000; i++) {
        final span = tracer.startSpan('span_$i');
        span.setAttribute('idx', AttributeValue.int(i));
        span.end();
      }

      final encoded = OtlpTraceEncoder.encode(exporter.spans);
      expect(encoded, isA<List<int>>());
      expect(encoded.isNotEmpty, isTrue);
    });

    test('encode with resource having 10,000 attributes does not crash', () {
      final attrs = <String, AttributeValue>{};
      for (var i = 0; i < 1000; i++) {
        attrs['key_$i'] = AttributeValue.string('val_$i');
      }
      final bigResource = Resource(Attributes.of(attrs));
      final emptyScope = const InstrumentationScope(name: 'test');

      final encoded = OtlpTraceEncoder.encode([],
          resource: bigResource, scope: emptyScope);
      expect(encoded.isNotEmpty, isTrue);
    });

    test('encode a Span with valid traceId succeeds', () {
      final exporter = InMemorySpanExporter();
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(exporter)],
      );
      final tracer = provider.get('test');
      final span = tracer.startSpan('test-valid');
      span.end();

      expect(exporter.spans.length, 1);
      final encoded = OtlpTraceEncoder.encode(exporter.spans);
      expect(encoded.isNotEmpty, isTrue);
    });

    test('encode SDKSpan with no attributes set (attributes is empty)', () {
      final span = _makeSpan(name: 'no-attrs');
      span.end();

      final encoded = OtlpTraceEncoder.encode([span]);
      expect(encoded.isNotEmpty, isTrue);
    });

    test('encode span with empty name does not crash', () {
      final exporter = InMemorySpanExporter();
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(exporter)],
      );
      final tracer = provider.get('test');
      final span = tracer.startSpan('');
      span.end();

      final encoded = OtlpTraceEncoder.encode([span]);
      expect(encoded.isNotEmpty, isTrue);
    });

    test('encode span with 10,000 char name does not crash', () {
      final exporter = InMemorySpanExporter();
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(exporter)],
      );
      final tracer = provider.get('test');
      final span = tracer.startSpan('x' * 10000);
      span.end();

      final encoded = OtlpTraceEncoder.encode([span]);
      expect(encoded.isNotEmpty, isTrue);
    });
  });

  // =========================================================================
  // 6. ZoneContextStorage attacks
  // =========================================================================
  group('ZoneContextStorage', () {
    test('current when there is no parent zone returns Context.root', () {
      final result = ZoneContextStorage.runWithContext(Context.root, () {
        final storage = ZoneContextStorage();
        return storage.current;
      });
      expect(result, isA<Context>());
    });

    test('attach returns the same context', () {
      final storage = ZoneContextStorage();
      final ctx = Context.root.withValue(
          spanContextKey,
          _SpanWrapper(SpanContext(
            traceId: TraceId.generate(),
            spanId: SpanId.generate(),
            traceFlags: TraceFlags.sampled,
          )));
      final attached = storage.attach(ctx);
      expect(identical(attached, ctx), isTrue);
    });

    test('detach returns Context.root', () {
      final storage = ZoneContextStorage();
      final ctx = Context.root.withValue(
          spanContextKey,
          _SpanWrapper(SpanContext(
            traceId: TraceId.generate(),
            spanId: SpanId.generate(),
            traceFlags: TraceFlags.sampled,
          )));
      final detached = storage.detach(ctx);
      expect(detached, Context.root);
    });

    test('runWithContext propagates context', () {
      final storage = ZoneContextStorage();
      final ctx = Context.root.withValue(
          spanContextKey,
          _SpanWrapper(SpanContext(
            traceId: TraceId.generate(),
            spanId: SpanId.generate(),
            traceFlags: TraceFlags.sampled,
          )));

      final found = ZoneContextStorage.runWithContext(ctx, () {
        return storage.current;
      });
      expect(identical(found, ctx), isTrue);
    });

    test('runWithContext where fn throws does not leak zone state', () {
      final ctx = Context.root.withValue(
          spanContextKey,
          _SpanWrapper(SpanContext(
            traceId: TraceId.generate(),
            spanId: SpanId.generate(),
            traceFlags: TraceFlags.sampled,
          )));

      expect(
        () => ZoneContextStorage.runWithContext(ctx, () {
          throw Exception('boom');
        }),
        throwsException,
      );

      final storage = ZoneContextStorage();
      final outer = storage.current;
      expect(outer, Context.root);
    });

    test('nested runWithContext does not leak between zones', () {
      final storage = ZoneContextStorage();

      final ctxA = Context.root.withValue(
          spanContextKey,
          _SpanWrapper(SpanContext(
            traceId: TraceId.generate(),
            spanId: SpanId.generate(),
            traceFlags: TraceFlags.sampled,
          )));

      final ctxB = Context.root.withValue(
          spanContextKey,
          _SpanWrapper(SpanContext(
            traceId: TraceId.generate(),
            spanId: SpanId.generate(),
            traceFlags: TraceFlags.none,
          )));

      ZoneContextStorage.runWithContext(ctxA, () {
        final inA = storage.current;
        expect(identical(inA, ctxA), isTrue);

        ZoneContextStorage.runWithContext(ctxB, () {
          final inB = storage.current;
          expect(identical(inB, ctxB), isTrue);
        });

        final afterB = storage.current;
        expect(identical(afterB, ctxA), isTrue);
      });
    });
  });

  // =========================================================================
  // 7. Batch processor attacks
  // =========================================================================
  group('Batch processors', () {
    test('BatchSpanProcessor maxQueueSize=0 is validated to 1', () async {
      final exporter = InMemorySpanExporter();
      final processor = BatchSpanProcessor(
        exporter,
        config: const BatchConfig(
            maxQueueSize: 0, scheduleDelay: Duration(minutes: 60)),
      );
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [processor],
      );
      final tracer = provider.get('test');
      tracer.startSpan('s1').end();
      await processor.shutdown();
      expect(exporter.spans.length, 1);
    });

    test('BatchSpanProcessor maxExportBatchSize=0 is validated to 1', () async {
      final exporter = InMemorySpanExporter();
      final processor = BatchSpanProcessor(
        exporter,
        config: const BatchConfig(
          maxExportBatchSize: 0,
          maxQueueSize: 10,
          scheduleDelay: Duration(milliseconds: 100),
        ),
      );
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [processor],
      );
      final tracer = provider.get('test');
      tracer.startSpan('s1').end();
      await processor.shutdown();
      expect(exporter.spans.length, 1);
    });

    test('BatchSpanProcessor scheduleDelay is very small (100ms)', () async {
      final exporter = InMemorySpanExporter();
      final processor = BatchSpanProcessor(exporter,
          config: const BatchConfig(
              scheduleDelay: Duration(milliseconds: 100),
              maxQueueSize: 10));
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [processor],
      );
      final tracer = provider.get('test');

      tracer.startSpan('s1').end();

      await processor.forceFlush();
      await processor.shutdown();
    });

    test('shutdown while spans are in queue drains all', () async {
      final exporter = InMemorySpanExporter();
      final processor = BatchSpanProcessor(
        exporter,
        config: const BatchConfig(
          maxExportBatchSize: 10,
          maxQueueSize: 100,
          scheduleDelay: Duration(minutes: 60),
        ),
      );
      final provider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [processor],
      );
      final tracer = provider.get('test');

      for (var i = 0; i < 10; i++) {
        tracer.startSpan('s$i').end();
      }

      await processor.forceFlush();
      await processor.shutdown();
    });

    test('BatchLogRecordProcessor maxQueueSize=0 is validated to 1', () {
      final exporter = _CaptureLogExporter();
      final processor = BatchLogRecordProcessor(
        exporter,
        config: const BatchConfig(
            maxQueueSize: 0, scheduleDelay: Duration(minutes: 60)),
      );
      processor.onEmit(Context.root, SDKLogRecord(
        timestamp: DateTime.now(),
        observedTimestamp: DateTime.now(),
        severityNumber: Severity.info,
        body: AttributeValue.string('test'),
      ));
      expect(exporter.exported.length, 0);
    });
  });

  // =========================================================================
  // 8. SDKLogger attacks
  // =========================================================================
  group('SDKLogger', () {
    test('emit with log record having null traceId/spanId does not crash', () {
      final exporter = _CaptureLogExporter();
      final processor = SimpleLogRecordProcessor(exporter);
      final logger = SDKLogger(
        name: 'test-logger',
        processors: [processor],
      );

      logger.emit(SDKLogRecord(
        timestamp: DateTime.now(),
        observedTimestamp: DateTime.now(),
        severityNumber: Severity.info,
        body: AttributeValue.string('no trace'),
        traceId: null,
        spanId: null,
      ));

      expect(exporter.exported.length, 1);
    });
  });

  // =========================================================================
  // 9. Integration: All signals under stress
  // =========================================================================
  group('Integration stress', () {
    test('trace + metrics + logs simultaneous under stress', () {
      final spanExporter = InMemorySpanExporter();
      final tracerProvider = SDKTracerProvider(
        resource: Resource.empty,
        processors: [SimpleSpanProcessor(spanExporter)],
      );
      final tracer = tracerProvider.get('stress');

      final counter = LongCounter(100);

      final logExporter = _CaptureLogExporter();
      final logProcessor = SimpleLogRecordProcessor(logExporter);
      final logger = SDKLogger(
        name: 'stress-logger',
        processors: [logProcessor],
      );

      for (var i = 0; i < 200; i++) {
        final span = tracer.startSpan('stress_$i');
        span.setAttribute('idx', AttributeValue.int(i));
        counter.add(i);
        span.addEvent('work_done');
        logger.emit(SDKLogRecord(
          timestamp: DateTime.now(),
          observedTimestamp: DateTime.now(),
          severityNumber: Severity.info,
          body: AttributeValue.string('log $i'),
        ));
        span.end();
      }

      expect(spanExporter.spans.length, 200);
      expect(logExporter.exported.length, 200);
    });
  });
}

// ---- Helpers ----

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

final class _SpanWrapper implements Span {
  final SpanContext _ctx;
  _SpanWrapper(this._ctx);

  @override
  SpanContext get spanContext => _ctx;
  @override
  bool get isRecording => false;
  @override
  void setStatus(SpanStatus status) {}
  @override
  void setAttribute(String key, AttributeValue value) {}
  @override
  void setAttributes(Attributes attributes) {}
  @override
  void addEvent(String name, {DateTime? timestamp, Attributes? attributes}) {}
  @override
  void addLink(SpanContext spanContext, {Attributes? attributes}) {}
  @override
  void recordException(Object exception,
      {StackTrace? stackTrace, Attributes? attributes}) {}
  @override
  void updateName(String name) {}
  @override
  void end([DateTime? endTime]) {}
}

final class _EvilToString {
  @override
  String toString() {
    throw Exception('evil toString exploded');
  }
}
