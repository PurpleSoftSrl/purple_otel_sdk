import 'package:purple_otel_api/purple_otel_api.dart';

import 'instruments.dart';
import 'metric_reader.dart';
import 'sdk_meter.dart';

final class SDKMeterProvider implements MeterProvider {
  final List<MetricReader> _readers;
  final Map<String, SDKMeter> _meters = {};

  final List<LongCounter> _allCounters = [];
  final List<DoubleCounter> _allDoubleCounters = [];
  final List<LongHistogramImpl> _allLongHistograms = [];
  final List<DoubleHistogramImpl> _allDoubleHistograms = [];

  SDKMeterProvider({
    required Resource resource,
    required List<MetricReader> readers,
    MetricCardinalityLimits? limits,
    List<View>? views,
  }) : _readers = List.unmodifiable(readers);

  @override
  SDKMeter get(String name, {String? version, String? schemaUrl}) {
    final key = '${name}\x00${version ?? ''}\x00${schemaUrl ?? ''}';
    return _meters.putIfAbsent(key, () => SDKMeter());
  }

  void registerCounter(LongCounter counter) {
    _allCounters.add(counter);
    for (final reader in _readers) {
      if (reader is PeriodicExportingMetricReader) {
        reader.registerCounter(counter);
      }
    }
  }

  void registerDoubleCounter(DoubleCounter counter) {
    _allDoubleCounters.add(counter);
    for (final reader in _readers) {
      if (reader is PeriodicExportingMetricReader) {
        reader.registerDoubleCounter(counter);
      }
    }
  }

  void registerLongHistogram(LongHistogramImpl hist) {
    _allLongHistograms.add(hist);
    for (final reader in _readers) {
      if (reader is PeriodicExportingMetricReader) {
        reader.registerLongHistogram(hist);
      }
    }
  }

  void registerDoubleHistogram(DoubleHistogramImpl hist) {
    _allDoubleHistograms.add(hist);
    for (final reader in _readers) {
      if (reader is PeriodicExportingMetricReader) {
        reader.registerDoubleHistogram(hist);
      }
    }
  }

  @override
  Future<void> forceFlush() async {
    await Future.wait(_readers.map((r) => r.forceFlush()));
  }

  @override
  Future<void> shutdown() async {
    _meters.clear();
    await Future.wait(_readers.map((r) => r.shutdown()));
  }
}
