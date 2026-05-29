import 'package:purple_otel_api/purple_otel_api.dart';

/// A single metric data point with attributes and a numeric value.
///
/// Used for counters, up-down counters, and gauge metric types.
final class MetricPoint {
  /// The attribute key-value pairs identifying this data point's dimension set.
  final Map<String, AttributeValue> attributes;

  /// The numeric value of this data point.
  final num value;

  /// Creates a [MetricPoint].
  const MetricPoint(this.attributes, this.value);
}

/// A single histogram data point with bucket counts and summary statistics.
final class HistogramPoint {
  /// The attribute key-value pairs identifying this data point's dimension set.
  final Map<String, AttributeValue> attributes;

  /// Total number of observations in the population.
  final int count;

  /// Sum of all observed values.
  final double sum;

  /// Minimum observed value.
  final double min;

  /// Maximum observed value.
  final double max;

  /// Upper bounds of each histogram bucket.
  final List<double> boundaries;

  /// Number of observations in each bucket.
  final List<int> bucketCounts;

  /// Creates a [HistogramPoint].
  const HistogramPoint({
    required this.attributes,
    required this.count,
    required this.sum,
    required this.min,
    required this.max,
    required this.boundaries,
    required this.bucketCounts,
  });
}

/// Enumerates the supported metric instrument types.
enum MetricType { counter, upDownCounter, histogram, gauge }

/// A collection of [MetricPoint] and [HistogramPoint] values exported together
/// with a shared timestamp.
///
/// Implements [Metric] for use with [MetricExporter].
final class MetricCollection implements Metric {
  /// Counter and up-down counter data points in this collection.
  final List<MetricPoint> counters;

  /// Gauge data points in this collection.
  final List<MetricPoint> gauges;

  /// Histogram data points in this collection.
  final List<HistogramPoint> histograms;

  /// The timestamp at which this collection was gathered.
  final DateTime timestamp;

  /// Creates a [MetricCollection].
  const MetricCollection({
    required this.counters,
    required this.gauges,
    required this.histograms,
    required this.timestamp,
  });
}
