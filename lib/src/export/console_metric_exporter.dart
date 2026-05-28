import 'package:purple_otel_api/purple_otel_api.dart';
import '../metrics/metric_data.dart';

final class ConsoleMetricExporter implements MetricExporter {
  final bool _pretty;

  const ConsoleMetricExporter({bool pretty = true}) : _pretty = pretty;

  @override
  Future<ExportResult> export(List<Metric> items) async {
    for (final item in items) {
      if (item is MetricCollection) {
        for (final counter in item.counters) {
          print('[METRIC] counter ${counter.attributes} = ${counter.value}');
        }
        for (final hist in item.histograms) {
          print('[METRIC] histogram ${hist.attributes} count=${hist.count} sum=${hist.sum} buckets=${hist.bucketCounts}');
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
