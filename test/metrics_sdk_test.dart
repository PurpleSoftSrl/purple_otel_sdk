import 'package:purple_otel_sdk/purple_otel_sdk.dart';
import 'package:test/test.dart';

final class _CaptureExporter implements MetricExporter {
  final List<Metric> exported = [];

  @override
  Future<ExportResult> export(List<Metric> items) async {
    exported.addAll(items);
    return ExportResult.success();
  }

  @override
  Future<void> shutdown() async {}
  @override
  Future<void> forceFlush() async {}
}

void main() {
  group('Counter', () {
    test('add accumulates values', () {
      final counter = LongCounter(100);
      counter.add(5);
      counter.add(3);
      final snapshot = counter.store.collectAndReset(false);
      expect(snapshot.values.first.value, 8);
    });

    test('different attributes create separate streams', () {
      final counter = LongCounter(100);
      counter.add(5,
          attributes: Attributes.of({'path': AttributeValue.string('/a')}));
      counter.add(3,
          attributes: Attributes.of({'path': AttributeValue.string('/b')}));
      expect(counter.store.activeStreams, 2);
    });

    test('same attributes reuse same stream', () {
      final counter = LongCounter(100);
      final attrs = Attributes.of({'path': AttributeValue.string('/a')});
      counter.add(1, attributes: attrs);
      counter.add(2, attributes: attrs);
      expect(counter.store.activeStreams, 1);
      final snapshot = counter.store.collectAndReset(false);
      expect(snapshot.values.first.value, 3);
    });

    test('cardinality limit drops overflow', () {
      final counter = LongCounter(2);
      counter.add(1,
          attributes: Attributes.of({'a': AttributeValue.string('1')}));
      counter.add(2,
          attributes: Attributes.of({'b': AttributeValue.string('2')}));
      counter.add(3,
          attributes: Attributes.of({'c': AttributeValue.string('3')}));
      expect(counter.store.activeStreams, 2);
      expect(counter.store.overflowCount, 1);
    });

    test('delta reset clears values after collect', () {
      final counter = LongCounter(100);
      counter.add(10);
      final snapshot1 = counter.store.collectAndReset(true);
      expect(snapshot1.values.first.value, 10);
      final snapshot2 = counter.store.collectAndReset(true);
      expect(snapshot2.isEmpty, isTrue);
    });
  });

  group('UpDownCounter', () {
    test('accepts negative values', () {
      final counter = LongUpDownCounter(100);
      counter.add(10);
      counter.add(-3);
      final snapshot = counter.store.collectAndReset(false);
      expect(snapshot.values.first.value, 7);
    });
  });

  group('Histogram', () {
    test('records values into correct buckets', () {
      final hist = DoubleHistogramImpl(boundaries: [1.0, 5.0, 10.0]);
      hist.record(0.5);
      hist.record(3.0);
      hist.record(7.0);
      hist.record(15.0);
      final snapshot = hist.store.collectAndReset(false);
      final agg = snapshot.values.first;
      expect(agg.count, 4);
      expect(agg.sum, closeTo(25.5, 0.01));
      expect(agg.bucketCounts[0], 1);
      expect(agg.bucketCounts[1], 1);
      expect(agg.bucketCounts[2], 1);
      expect(agg.bucketCounts[3], 1);
      expect(agg.min, closeTo(0.5, 0.01));
      expect(agg.max, closeTo(15.0, 0.01));
    });
  });

  group('SDKMeter', () {
    test('creates instruments of correct types', () {
      final meter = SDKMeter();
      expect(meter.createCounter('c'), isA<LongCounter>());
      expect(meter.createUpDownCounter('u'), isA<LongUpDownCounter>());
      expect(meter.createDoubleHistogram('h'), isA<DoubleHistogramImpl>());
      expect(meter.createLongHistogram('lh'), isA<LongHistogramImpl>());
    });
  });

  group('SDKMeterProvider', () {
    test('get returns cached meter', () {
      final provider = SDKMeterProvider(resource: Resource.empty, readers: []);
      final m1 = provider.get('test');
      final m2 = provider.get('test');
      expect(identical(m1, m2), isTrue);
    });
  });

  group('PeriodicExportingMetricReader', () {
    test('collects and exports counter data', () async {
      final exporter = _CaptureExporter();
      final reader = PeriodicExportingMetricReader(
        exporter: exporter,
        interval: const Duration(seconds: 60),
      );
      final counter = LongCounter(100);
      reader.registerCounter(counter);
      counter.add(42);
      await reader.forceFlush();
      expect(exporter.exported.length, 1);
      final collection = exporter.exported.first as MetricCollection;
      expect(collection.counters.length, 1);
      expect(collection.counters.first.value, 42);
      await reader.shutdown();
    });

    test('delta mode resets counters after collection', () async {
      final exporter = _CaptureExporter();
      final reader = PeriodicExportingMetricReader(
        exporter: exporter,
        interval: const Duration(seconds: 60),
        temporality: Temporality.delta,
      );
      final counter = LongCounter(100);
      reader.registerCounter(counter);
      counter.add(10);
      await reader.forceFlush();
      expect((exporter.exported.first as MetricCollection).counters.first.value,
          10);
      counter.add(15);
      await reader.forceFlush();
      expect(exporter.exported.length, 2);
      expect(
          (exporter.exported[1] as MetricCollection).counters.first.value, 15);
      await reader.shutdown();
    });
  });

  group('ConsoleMetricExporter', () {
    test('export returns success', () async {
      const exporter = ConsoleMetricExporter();
      final result = await exporter.export([
        MetricCollection(
            counters: [],
            gauges: [],
            histograms: [],
            timestamp: DateTime.now()),
      ]);
      expect(result.isSuccess, isTrue);
    });
  });
}
