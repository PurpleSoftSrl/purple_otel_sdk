import 'package:http/http.dart' as http;
import 'package:purple_otel_sdk/purple_otel_sdk.dart' show Tracer, SpanKind, spanContextKey, Context, AttributeValue, W3CTraceContextPropagator, SpanStatus;

final class OtelHttpClient extends http.BaseClient {
  final http.Client _inner;
  final Tracer _tracer;
  final SpanKind _kind;

  OtelHttpClient({
    required http.Client inner,
    required Tracer tracer,
    SpanKind kind = SpanKind.client,
  })  : _inner = inner,
        _tracer = tracer,
        _kind = kind;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final span = _tracer.startSpan(
      '${request.method} ${request.url.host}${request.url.path}',
      kind: _kind,
    );

    span.setAttribute('http.method', AttributeValue.string(request.method));
    span.setAttribute('http.url', AttributeValue.string(request.url.toString()));
    span.setAttribute('http.host', AttributeValue.string(request.url.host));

    final carrier = <String, String>{};
    final ctx = Context.root.withValue(spanContextKey, span);
    W3CTraceContextPropagator.inject(ctx, carrier);

    for (final entry in carrier.entries) {
      request.headers[entry.key] = entry.value;
    }

    http.StreamedResponse response;
    try {
      response = await _inner.send(request);
    } catch (e, st) {
      span.recordException(e, stackTrace: st);
      span.setStatus(SpanStatus.error('${request.method} failed: $e'));
      span.end();
      rethrow;
    }

    span.setAttribute('http.status_code', AttributeValue.int(response.statusCode));

    if (response.statusCode >= 500) {
      span.setStatus(SpanStatus.error('HTTP ${response.statusCode}'));
    } else if (response.statusCode >= 400) {
      span.setStatus(SpanStatus.error('HTTP ${response.statusCode}'));
    } else {
      span.setStatus(SpanStatus.ok);
    }

    span.end();
    return response;
  }

  @override
  void close() => _inner.close();
}
