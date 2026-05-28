import 'package:purple_otel_api/purple_otel_api.dart';

import '../otlp/otlp_trace_encoder.dart';
import 'otlp_http_client.dart';

final class OtlpHttpSpanExporter implements SpanExporter {
  final OtlpHttpClient _client;
  final Resource? _resource;
  final InstrumentationScope? _scope;

  OtlpHttpSpanExporter({
    required Uri endpoint,
    Map<String, String>? headers,
    Resource? resource,
    InstrumentationScope? scope,
    int timeoutMs = 10000,
  })  : _client = OtlpHttpClient(endpoint: endpoint, headers: headers, timeoutMs: timeoutMs),
        _resource = resource,
        _scope = scope;

  @override
  Future<ExportResult> export(List<Span> items) async {
    if (items.isEmpty) return ExportResult.success();
    try {
      final body = OtlpTraceEncoder.encode(items, resource: _resource, scope: _scope);
      final status = await _client.send('/v1/traces', body);
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
  Future<void> shutdown() async {
    _client.close();
  }

  @override
  Future<void> forceFlush() async {}
}
