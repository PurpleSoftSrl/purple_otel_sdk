import 'package:http/http.dart' as http;
import 'package:purple_otel_sdk/purple_otel_sdk.dart'
    show
        Tracer,
        SpanKind,
        spanContextKey,
        Context,
        AttributeValue,
        W3CTraceContextPropagator,
        SpanStatus;

/// An `http.BaseClient` wrapper that automatically instruments outgoing HTTP
/// requests with tracing spans.
///
/// Each request creates a span named `"{METHOD} {host}{path}"` with attributes
/// for the HTTP method, URL, and host. W3C trace context headers are injected
/// via [W3CTraceContextPropagator]. Response status codes set the span status:
/// 5xx and 4xx result in an error status; otherwise [SpanStatus.ok].
final class OtelHttpClient extends http.BaseClient {
  final http.Client _inner;
  final Tracer _tracer;
  final SpanKind _kind;

  /// Creates an [OtelHttpClient].
  ///
  /// [inner] is the underlying HTTP client that performs the actual request.
  /// [tracer] creates spans for each HTTP request.
  /// [kind] indicates the span role; defaults to [SpanKind.client].
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
    span.setAttribute(
        'http.url', AttributeValue.string(request.url.toString()));
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

    span.setAttribute(
        'http.status_code', AttributeValue.int(response.statusCode));

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
