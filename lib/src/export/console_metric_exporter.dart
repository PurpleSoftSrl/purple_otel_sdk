import 'package:purple_otel_api/purple_otel_api.dart';
import '../metrics/metric_data.dart';

/// A [MetricExporter] that writes metric data points to `stdout` for debugging.
///
/// Does not connect to any backend; output is printed via `print()`.
final class ConsoleMetricExporter implements MetricExporter {
  /// Creates a [ConsoleMetricExporter].
  const ConsoleMetricExporter();

  @override
  Future<ExportResult> export(List<Metric> items) async {
    for (final item in items) {
      if (item is MetricCollection) {
        for (final counter in item.counters) {
          print('[METRIC] counter ${counter.attributes} = ${counter.value}');
        }
        for (final hist in item.histograms) {
          print(
              '[METRIC] histogram ${hist.attributes} count=${hist.count} sum=${hist.sum} buckets=${hist.bucketCounts}');
        }
      }
    }
    return ExportResult.success();
  }

  @override
  Future<void> shutdown() async {}

  @override
  Future<void> forceFlush() async {}
}
