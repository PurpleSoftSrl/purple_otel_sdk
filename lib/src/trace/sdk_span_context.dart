import 'dart:math';
import 'dart:typed_data';

import 'package:purple_otel_api/purple_otel_api.dart';

final class SDKSpanContext {
  final TraceId traceId;
  final SpanId spanId;
  final TraceFlags traceFlags;
  final TraceState traceState;
  final bool isRemote;

  const SDKSpanContext({
    required this.traceId,
    required this.spanId,
    required this.traceFlags,
    this.traceState = const TraceState.empty(),
    this.isRemote = false,
  });

  static final SDKSpanContext invalid = SDKSpanContext(
    traceId: TraceId.invalid(),
    spanId: SpanId.invalid(),
    traceFlags: TraceFlags.none,
  );

  SpanContext toApi() => SpanContext(
        traceId: traceId,
        spanId: spanId,
        traceFlags: traceFlags,
        traceState: traceState,
        isRemote: isRemote,
      );
}

final class RandomIdGenerator implements IdGenerator {
  final Random _random = Random.secure();

  @override
  TraceId generateTraceId() {
    final bytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return TraceId.fromBytes(bytes);
  }

  @override
  SpanId generateSpanId() {
    final bytes = Uint8List(8);
    for (var i = 0; i < 8; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return SpanId.fromBytes(bytes);
  }
}
