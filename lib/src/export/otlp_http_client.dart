import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Low-level HTTP client for sending Protobuf-encoded OTLP payloads to a
/// collector endpoint.
///
/// Sends binary Protobuf (`Content-Type: application/x-protobuf`) via HTTP POST.
/// Supports configurable retries with exponential backoff for server errors
/// (HTTP 5xx and 429).
final class OtlpHttpClient {
  final Uri _endpoint;
  final Map<String, String> _headers;
  final http.Client _client;
  final int _timeoutMs;
  final int _maxAttempts;

  /// Creates an [OtlpHttpClient].
  ///
  /// [endpoint] is the base URL of the OTLP collector (e.g. `http://localhost:4318`).
  /// [headers] are additional HTTP headers included with every request.
  /// [client] is an optional `http.Client` for custom connection pooling.
  /// [timeoutMs] is the per-request timeout in milliseconds; defaults to `10000`.
  /// [maxAttempts] is the maximum number of retry attempts; defaults to `3`.
  OtlpHttpClient({
    required Uri endpoint,
    Map<String, String>? headers,
    http.Client? client,
    int timeoutMs = 10000,
    int maxAttempts = 3,
  })  : _endpoint = endpoint,
        _headers = {
          'Content-Type': 'application/x-protobuf',
          if (headers != null) ...headers,
        },
        _client = client ?? http.Client(),
        _timeoutMs = timeoutMs,
        _maxAttempts = maxAttempts;

  /// Sends a Protobuf-encoded [body] to the given [path] on the configured endpoint.
  ///
  /// Returns the HTTP status code. Retries on server errors (5xx, 429) with
  /// exponential backoff up to [maxAttempts] times. On success, returns 200 or 204.
  Future<int> send(String path, Uint8List body) async {
    var lastStatus = 0;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      try {
        final uri = _endpoint.resolve(path);
        final response = await _client
            .post(uri, headers: _headers, body: body)
            .timeout(Duration(milliseconds: _timeoutMs));

        lastStatus = response.statusCode;
        if (response.statusCode == 200 || response.statusCode == 204) {
          return response.statusCode;
        }
        if (response.statusCode >= 500 || response.statusCode == 429) {
          await Future.delayed(Duration(milliseconds: (attempt + 1) * 200));
          continue;
        }
        return response.statusCode;
      } on Exception {
        lastStatus = 503;
        await Future.delayed(Duration(milliseconds: (attempt + 1) * 200));
      }
    }
    return lastStatus;
  }

  /// Closes the underlying HTTP client.
  void close() {
    _client.close();
  }
}
