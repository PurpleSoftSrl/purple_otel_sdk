import 'package:purple_otel_api/purple_otel_api.dart';

import 'instruments.dart';
import 'metric_reader.dart';
import 'sdk_meter.dart';

/// The flagship SDK implementation of [MeterProvider].
///
/// Creates and caches [SDKMeter] instances keyed by instrumentation scope.
/// Maintains global registries of all created instruments so that configured
/// [MetricReader] instances can collect and export metric data on demand.
final class SDKMeterProvider implements MeterProvider {
  final List<MetricReader> _readers;
  final Map<String, SDKMeter> _meters = {};

  final List<LongCounter> _allCounters = [];
  final List<DoubleCounter> _allDoubleCounters = [];
  final List<LongHistogramImpl> _allLongHistograms = [];
  final List<DoubleHistogramImpl> _allDoubleHistograms = [];

  /// Creates an [SDKMeterProvider].
  ///
  /// [resource] is the entity producing telemetry.
  /// [readers] are [MetricReader] instances that collect and export metrics.
  /// [limits] constrain attribute cardinality per metric stream.
  /// [views] define aggregation and attribute transformations.
  SDKMeterProvider({
    required Resource resource,
    required List<MetricReader> readers,
    MetricCardinalityLimits? limits,
    List<View>? views,
  }) : _readers = List.unmodifiable(readers);

  /// Returns or creates a cached [SDKMeter] for the given instrumentation scope.
  ///
  /// [name] identifies the instrumentation library. [version] and [schemaUrl]
  /// are optional scope attributes.
  @override
  SDKMeter get(String name, {String? version, String? schemaUrl}) {
    final key = '${name}\x00${version ?? ''}\x00${schemaUrl ?? ''}';
    return _meters.putIfAbsent(key, () => SDKMeter());
  }

  /// Registers a [LongCounter] to be collected by all [PeriodicExportingMetricReader] instances.
  void registerCounter(LongCounter counter) {
    _allCounters.add(counter);
    for (final reader in _readers) {
      if (reader is PeriodicExportingMetricReader) {
        reader.registerCounter(counter);
      }
    }
  }

  /// Registers a [DoubleCounter] to be collected by all [PeriodicExportingMetricReader] instances.
  void registerDoubleCounter(DoubleCounter counter) {
    _allDoubleCounters.add(counter);
    for (final reader in _readers) {
      if (reader is PeriodicExportingMetricReader) {
        reader.registerDoubleCounter(counter);
      }
    }
  }

  /// Registers a [LongHistogramImpl] to be collected by all [PeriodicExportingMetricReader] instances.
  void registerLongHistogram(LongHistogramImpl hist) {
    _allLongHistograms.add(hist);
    for (final reader in _readers) {
      if (reader is PeriodicExportingMetricReader) {
        reader.registerLongHistogram(hist);
      }
    }
  }

  /// Registers a [DoubleHistogramImpl] to be collected by all [PeriodicExportingMetricReader] instances.
  void registerDoubleHistogram(DoubleHistogramImpl hist) {
    _allDoubleHistograms.add(hist);
    for (final reader in _readers) {
      if (reader is PeriodicExportingMetricReader) {
        reader.registerDoubleHistogram(hist);
      }
    }
  }

  /// Forces all registered [MetricReader] instances to collect and export.
  @override
  Future<void> forceFlush() async {
    await Future.wait(_readers.map((r) => r.forceFlush()));
  }

  /// Shuts down all readers and clears the meter cache.
  @override
  Future<void> shutdown() async {
    _meters.clear();
    await Future.wait(_readers.map((r) => r.shutdown()));
  }
}
