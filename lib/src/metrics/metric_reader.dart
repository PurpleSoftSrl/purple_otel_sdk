import 'dart:async';

import 'package:purple_otel_api/purple_otel_api.dart';

import 'instruments.dart';
import 'metric_data.dart';

enum Temporality { delta, cumulative }

final class PeriodicExportingMetricReader implements MetricReader {
  final MetricExporter _exporter;
  final Temporality _temporality;
  Timer? _timer;
  bool _shutdown = false;

  final List<LongCounter> _counters = [];
  final List<DoubleCounter> _doubleCounters = [];
  final List<LongUpDownCounter> _upDownCounters = [];
  final List<DoubleUpDownCounter> _doubleUpDownCounters = [];
  final List<LongHistogramImpl> _longHistograms = [];
  final List<DoubleHistogramImpl> _doubleHistograms = [];

  PeriodicExportingMetricReader({
    required MetricExporter exporter,
    Duration interval = const Duration(seconds: 60),
    Temporality temporality = Temporality.delta,
  })  : _exporter = exporter,
        _temporality = temporality {
    _timer = Timer.periodic(interval, (_) => _collectAndExport());
  }

  void registerCounter(LongCounter counter) => _counters.add(counter);
  void registerDoubleCounter(DoubleCounter counter) => _doubleCounters.add(counter);
  void registerUpDownCounter(LongUpDownCounter counter) => _upDownCounters.add(counter);
  void registerDoubleUpDownCounter(DoubleUpDownCounter counter) => _doubleUpDownCounters.add(counter);
  void registerLongHistogram(LongHistogramImpl histogram) => _longHistograms.add(histogram);
  void registerDoubleHistogram(DoubleHistogramImpl histogram) => _doubleHistograms.add(histogram);

  void _collectAndExport() {
    if (_shutdown) return;
    final timestamp = DateTime.now();
    final counters = <MetricPoint>[];
    final histograms = <HistogramPoint>[];

    for (final c in _counters) {
      final attrsBefore = c.store.cardinality.snapshotAttributes();
      final snapshot = c.store.collectAndReset(_temporality == Temporality.delta);
      for (final entry in snapshot.entries) {
        final attrs = attrsBefore[entry.key];
        if (attrs != null) {
          final map = <String, AttributeValue>{};
          for (final k in attrs.entries.keys) {
            map[k] = attrs.entries[k]!;
          }
          counters.add(MetricPoint(map, entry.value.value));
        }
      }
    }

    for (final c in _doubleCounters) {
      final snapshot = c.store.collectAndReset(_temporality == Temporality.delta);
      for (final entry in snapshot.entries) {
        final attrs = c.store.cardinality.getAttributes(entry.key);
        if (attrs != null) {
          final map = <String, AttributeValue>{};
          for (final k in attrs.entries.keys) {
            map[k] = attrs.entries[k]!;
          }
          counters.add(MetricPoint(map, entry.value.value));
        }
      }
    }

    for (final h in _doubleHistograms) {
      final snapshot = h.store.collectAndReset(_temporality == Temporality.delta);
      for (final entry in snapshot.entries) {
        final attrs = h.store.cardinality.getAttributes(entry.key);
        if (attrs != null) {
          final map = <String, AttributeValue>{};
          for (final k in attrs.entries.keys) {
            map[k] = attrs.entries[k]!;
          }
          histograms.add(HistogramPoint(
            attributes: map,
            count: entry.value.count,
            sum: entry.value.sum,
            min: entry.value.min,
            max: entry.value.max,
            boundaries: entry.value.boundaries,
            bucketCounts: entry.value.bucketCounts.toList(),
          ));
        }
      }
    }

    if (counters.isNotEmpty || histograms.isNotEmpty) {
      final collection = MetricCollection(
        counters: counters,
        gauges: [],
        histograms: histograms,
        timestamp: timestamp,
      );
      _exporter.export([collection]);
    }
  }

  @override
  Future<void> forceFlush() async {
    _collectAndExport();
  }

  @override
  Future<void> shutdown() async {
    _shutdown = true;
    _timer?.cancel();
    _collectAndExport();
    await _exporter.shutdown();
  }
}
