import 'dart:typed_data';

import 'package:purple_otel_api/purple_otel_api.dart';
import '../metrics/metric_data.dart';
import '../metrics/aggregation.dart';
import '../metrics/instruments.dart';
import '../otlp/protobuf_writer.dart';
import '../otlp/otlp_common_encoder.dart';

abstract final class OtlpMetricEncoder {
  static Uint8List encode(List<Metric> metrics, {Resource? resource, InstrumentationScope? scope}) {
    final request = ProtobufWriter();
    final resourceMetrics = ProtobufWriter();

    if (resource != null) {
      OtlpCommonEncoder.encodeResource(resourceMetrics, 1, resource);
    }

    final scopeMetrics = ProtobufWriter();
    if (scope != null) {
      OtlpCommonEncoder.encodeInstrumentationScope(scopeMetrics, 1, scope);
    }

    for (final metric in metrics) {
      if (metric is MetricCollection) {
        for (final counter in metric.counters) {
          final m = ProtobufWriter();
          m.writeString(1, 'counter');
          _encodeSum(m, counter);
          scopeMetrics.writeMessage(2, m);
        }
        for (final hist in metric.histograms) {
          final m = ProtobufWriter();
          m.writeString(1, 'histogram');
          _encodeHistogram(m, hist);
          scopeMetrics.writeMessage(2, m);
        }
      }
    }

    resourceMetrics.writeMessage(2, scopeMetrics);
    request.writeMessage(1, resourceMetrics);
    return request.toBytes();
  }

  static void _encodeSum(ProtobufWriter w, MetricPoint point) {
    final sum = ProtobufWriter();
    if (point.value is int) {
      sum.writeInt64(4, point.value as int);
    } else {
      sum.writeDouble(4, point.value.toDouble());
    }
    sum.writeInt32(5, 1); // monotonic
    sum.writeInt32(6, 1); // delta
    w.writeMessage(7, sum); // int_sum or double_sum
  }

  static void _encodeHistogram(ProtobufWriter w, HistogramPoint point) {
    final hist = ProtobufWriter();
    hist.writeInt64(2, point.count);
    hist.writeDouble(3, point.sum);
    // explicit bucket boundaries
    for (final b in point.boundaries) {
      hist.writeDouble(4, b);
    }
    // bucket counts
    for (final c in point.bucketCounts) {
      hist.writeInt64(5, c);
    }
    // min, max
    hist.writeDouble(6, point.min);
    hist.writeDouble(7, point.max);
    w.writeMessage(9, hist);
  }
}
