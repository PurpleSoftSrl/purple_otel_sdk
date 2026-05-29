import 'dart:math';
import 'dart:typed_data';

import 'package:purple_otel_api/purple_otel_api.dart';

/// The SDK's internal representation of a span context.
///
/// Wraps OpenTelemetry identity fields (trace ID, span ID, trace flags) plus
/// [TraceState] and an [isRemote] flag indicating whether the context was
/// propagated from a remote service. Use [toApi] to convert to the public
/// [SpanContext] type.
final class SDKSpanContext {
  /// The trace identifier shared by all spans in the same trace.
  final TraceId traceId;

  /// The unique identifier for this individual span.
  final SpanId spanId;

  /// Flags encoding properties such as whether the trace is sampled.
  final TraceFlags traceFlags;

  /// Vendor-specific trace state propagated across context boundaries.
  final TraceState traceState;

  /// Whether this context was received from a remote service.
  final bool isRemote;

  /// Creates an [SDKSpanContext].
  ///
  /// [isRemote] defaults to `false`, indicating a locally-created span.
  const SDKSpanContext({
    required this.traceId,
    required this.spanId,
    required this.traceFlags,
    this.traceState = const TraceState.empty(),
    this.isRemote = false,
  });

  /// An invalid span context with all-zero trace and span IDs.
  static final SDKSpanContext invalid = SDKSpanContext(
    traceId: TraceId.invalid(),
    spanId: SpanId.invalid(),
    traceFlags: TraceFlags.none,
  );

  /// Converts this SDK span context to the public [SpanContext] API type.
  SpanContext toApi() => SpanContext(
        traceId: traceId,
        spanId: spanId,
        traceFlags: traceFlags,
        traceState: traceState,
        isRemote: isRemote,
      );
}

/// Generates W3C-compliant trace and span IDs using a cryptographically secure
/// random number generator.
///
/// Trace IDs are 16 bytes, span IDs are 8 bytes, per the W3C Trace Context
/// specification.
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
