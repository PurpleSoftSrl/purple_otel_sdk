import 'dart:typed_data';

import 'package:http/http.dart' as http;

final class OtlpHttpClient {
  final Uri _endpoint;
  final Map<String, String> _headers;
  final http.Client _client;
  final int _timeoutMs;
  final int _maxAttempts;

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

  void close() {
    _client.close();
  }
}
