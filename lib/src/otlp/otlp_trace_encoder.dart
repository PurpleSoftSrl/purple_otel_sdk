import 'dart:typed_data';

import 'package:purple_otel_api/purple_otel_api.dart';
import '../trace/sdk_span.dart';
import 'protobuf_writer.dart';
import 'otlp_common_encoder.dart';

abstract final class OtlpTraceEncoder {
  static Uint8List encode(List<Span> spans,
      {Resource? resource, InstrumentationScope? scope}) {
    final request = ProtobufWriter();

    final resourceSpans = ProtobufWriter();

    if (resource != null) {
      OtlpCommonEncoder.encodeResource(resourceSpans, 1, resource);
    }

    final scopeSpans = ProtobufWriter();
    if (scope != null) {
      OtlpCommonEncoder.encodeInstrumentationScope(scopeSpans, 1, scope);
    }

    for (final span in spans) {
      if (span is! SDKSpan) continue;
      final spanMsg = ProtobufWriter();

      spanMsg.writeBytes(1, span.spanContext.traceId.bytes);
      spanMsg.writeBytes(2, span.spanContext.spanId.bytes);
      spanMsg.writeString(4, span.name);
      spanMsg.writeInt32(5, _encodeKind(span.kind));
      spanMsg.writeFixed64(6, _nanoTime(span.startTime));
      spanMsg.writeFixed64(7, _nanoTime(span.endTime ?? span.startTime));

      for (final entry in span.attributes.entries) {
        OtlpCommonEncoder.encodeKeyValue(spanMsg, 8, entry.key, entry.value);
      }

      spanMsg.writeUint32(9, 0);

      for (final event in span.events) {
        final eventMsg = ProtobufWriter();
        eventMsg.writeFixed64(1, _nanoTime(event.timestamp));
        eventMsg.writeString(2, event.name);
        if (event.attributes != null) {
          for (final key in event.attributes!.entries.keys) {
            OtlpCommonEncoder.encodeKeyValue(
                eventMsg, 3, key, event.attributes!.entries[key]!);
          }
        }
        spanMsg.writeMessage(10, eventMsg);
      }

      spanMsg.writeUint32(11, 0);

      for (final link in span.links) {
        final linkMsg = ProtobufWriter();
        linkMsg.writeBytes(1, link.spanContext.traceId.bytes);
        linkMsg.writeBytes(2, link.spanContext.spanId.bytes);
        if (link.attributes != null) {
          for (final key in link.attributes!.entries.keys) {
            OtlpCommonEncoder.encodeKeyValue(
                linkMsg, 4, key, link.attributes!.entries[key]!);
          }
        }
        spanMsg.writeMessage(12, linkMsg);
      }

      final statusMsg = ProtobufWriter();
      final status = span.status;
      if (status.code == StatusCode.ok) {
        statusMsg.writeInt32(1, 1);
      } else if (status.code == StatusCode.error) {
        statusMsg.writeInt32(1, 2);
      }
      if (status.description != null) {
        statusMsg.writeString(2, status.description!);
      }
      spanMsg.writeMessage(14, statusMsg);

      scopeSpans.writeMessage(2, spanMsg);
    }

    resourceSpans.writeMessage(2, scopeSpans);
    request.writeMessage(1, resourceSpans);

    return request.toBytes();
  }

  static int _encodeKind(SpanKind kind) {
    switch (kind) {
      case SpanKind.internal:
        return 1;
      case SpanKind.server:
        return 2;
      case SpanKind.client:
        return 3;
      case SpanKind.producer:
        return 4;
      case SpanKind.consumer:
        return 5;
    }
  }

  static int _nanoTime(DateTime dt) => dt.microsecondsSinceEpoch * 1000;
}
