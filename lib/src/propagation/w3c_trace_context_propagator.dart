import 'dart:typed_data';

import 'package:purple_otel_api/purple_otel_api.dart';

final class W3CTraceContextPropagator {
  static const String _traceParentHeader = 'traceparent';
  static const String _traceStateHeader = 'tracestate';

  static void inject(Context context, Map<String, String> carrier) {
    final span = context.span;
    if (span == null || !span.spanContext.isValid) return;

    final ctx = span.spanContext;
    final traceId = ctx.traceId.toString();
    final spanId = ctx.spanId.toString();
    final flags = ctx.traceFlags.isSampled ? '01' : '00';

    carrier[_traceParentHeader] = '00-$traceId-$spanId-$flags';

    final traceState = ctx.traceState.toString();
    if (traceState.isNotEmpty) {
      carrier[_traceStateHeader] = traceState;
    }
  }

  static Context extract(Context context, Map<String, String> carrier) {
    final traceParent = carrier[_traceParentHeader];
    if (traceParent == null) return context;

    final parts = traceParent.split('-');
    if (parts.length != 4) return context;
    if (parts[0] != '00') return context;

    final traceId = _parseHexBytes(parts[1], 16);
    final spanId = _parseHexBytes(parts[2], 8);
    final flags = _parseHexByte(parts[3]);

    if (traceId == null || spanId == null || flags == null) return context;

    return context;
  }

  static Uint8List? _parseHexBytes(String hex, int expectedLength) {
    if (hex.length != expectedLength * 2) return null;
    try {
      final bytes = Uint8List(expectedLength);
      for (var i = 0; i < expectedLength; i++) {
        bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static int? _parseHexByte(String hex) {
    try {
      return int.parse(hex, radix: 16);
    } catch (_) {
      return null;
    }
  }
}
