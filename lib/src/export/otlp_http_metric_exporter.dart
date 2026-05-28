import 'package:purple_otel_api/purple_otel_api.dart';
import '../otlp/otlp_metric_encoder.dart';
import 'otlp_http_client.dart';

final class OtlpHttpMetricExporter implements MetricExporter {
  final OtlpHttpClient _client;
  final Resource? _resource;
  final InstrumentationScope? _scope;

  OtlpHttpMetricExporter({
    required Uri endpoint,
    Map<String, String>? headers,
    Resource? resource,
    InstrumentationScope? scope,
    int timeoutMs = 10000,
  })  : _client = OtlpHttpClient(endpoint: endpoint, headers: headers, timeoutMs: timeoutMs),
        _resource = resource,
        _scope = scope;

  @override
  Future<ExportResult> export(List<Metric> items) async {
    if (items.isEmpty) return ExportResult.success();
    try {
      final body = OtlpMetricEncoder.encode(items, resource: _resource, scope: _scope);
      final status = await _client.send('/v1/metrics', body);
      if (status == 200 || status == 204) {
        return ExportResult.success();
      }
      if (status >= 500 || status == 429) {
        return ExportResult.failureRetryable('HTTP $status');
      }
      return ExportResult.failureNotRetryable('HTTP $status');
    } catch (e) {
      return ExportResult.failureRetryable(e.toString());
    }
  }

  @override
  Future<void> shutdown() async => _client.close();

  @override
  Future<void> forceFlush() async {}
}
