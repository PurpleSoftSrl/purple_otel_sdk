import 'package:purple_otel_api/purple_otel_api.dart';

final class MetricPoint {
  final Map<String, AttributeValue> attributes;
  final num value;

  const MetricPoint(this.attributes, this.value);
}

final class HistogramPoint {
  final Map<String, AttributeValue> attributes;
  final int count;
  final double sum;
  final double min;
  final double max;
  final List<double> boundaries;
  final List<int> bucketCounts;

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

enum MetricType { counter, upDownCounter, histogram, gauge }

final class MetricCollection implements Metric {
  final List<MetricPoint> counters;
  final List<MetricPoint> gauges;
  final List<HistogramPoint> histograms;
  final DateTime timestamp;

  const MetricCollection({
    required this.counters,
    required this.gauges,
    required this.histograms,
    required this.timestamp,
  });
}
