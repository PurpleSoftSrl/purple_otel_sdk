import 'package:purple_otel_api/purple_otel_api.dart';

import '../otlp/otlp_log_encoder.dart';
import 'otlp_http_client.dart';

/// An [LogRecordExporter] that sends log records to an OTLP collector via
/// HTTP/protobuf.
///
/// Encodes records using [OtlpLogEncoder] and POSTs to `{endpoint}/v1/logs`.
/// Supports retryable and non-retryable error classification.
final class OtlpHttpLogRecordExporter implements LogRecordExporter {
  final OtlpHttpClient _client;
  final Resource? _resource;
  final InstrumentationScope? _scope;

  /// Creates an [OtlpHttpLogRecordExporter].
  ///
  /// [endpoint] is the base URL of the OTLP collector.
  /// [headers] are optional additional HTTP headers.
  /// [resource] is attached to exported payloads as resource attributes.
  /// [scope] identifies the instrumentation source.
  /// [timeoutMs] is the per-request timeout in milliseconds; defaults to `10000`.
  OtlpHttpLogRecordExporter({
    required Uri endpoint,
    Map<String, String>? headers,
    Resource? resource,
    InstrumentationScope? scope,
    int timeoutMs = 10000,
  })  : _client = OtlpHttpClient(
            endpoint: endpoint, headers: headers, timeoutMs: timeoutMs),
        _resource = resource,
        _scope = scope;

  @override
  Future<ExportResult> export(List<LogRecord> items) async {
    if (items.isEmpty) return ExportResult.success();
    try {
      final body =
          OtlpLogEncoder.encode(items, resource: _resource, scope: _scope);
      final status = await _client.send('/v1/logs', body);
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
