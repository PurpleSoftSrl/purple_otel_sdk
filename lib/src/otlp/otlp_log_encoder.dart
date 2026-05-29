import 'dart:typed_data';

import 'package:purple_otel_api/purple_otel_api.dart';
import 'protobuf_writer.dart';
import 'otlp_common_encoder.dart';

abstract final class OtlpLogEncoder {
  static Uint8List encode(List<LogRecord> records,
      {Resource? resource, InstrumentationScope? scope}) {
    final request = ProtobufWriter();

    final resourceLogs = ProtobufWriter();

    if (resource != null) {
      OtlpCommonEncoder.encodeResource(resourceLogs, 1, resource);
    }

    final scopeLogs = ProtobufWriter();
    if (scope != null) {
      OtlpCommonEncoder.encodeInstrumentationScope(scopeLogs, 1, scope);
    }

    for (final record in records) {
      final logRecord = ProtobufWriter();

      logRecord.writeFixed64(1, _nanoTime(record.timestamp));
      logRecord.writeFixed64(2, _nanoTime(record.observedTimestamp));
      logRecord.writeInt32(4, record.severityNumber.value);
      if (record.severityText != null) {
        logRecord.writeString(5, record.severityText!);
      }
      OtlpCommonEncoder.encodeAnyValue(logRecord, 6, record.body);

      for (final entry in record.attributes.entries.entries) {
        OtlpCommonEncoder.encodeKeyValue(logRecord, 7, entry.key, entry.value);
      }

      logRecord.writeUint32(8, record.droppedAttributesCount);

      if (record.traceId != null && record.traceId!.isValid) {
        logRecord.writeBytes(9, record.traceId!.bytes);
      }
      if (record.spanId != null && record.spanId!.isValid) {
        logRecord.writeBytes(10, record.spanId!.bytes);
      }
      if (record.traceFlags != null) {
        logRecord.writeFixed64(11, record.traceFlags!.value);
      }

      scopeLogs.writeMessage(2, logRecord);
    }

    resourceLogs.writeMessage(2, scopeLogs);
    request.writeMessage(1, resourceLogs);

    return request.toBytes();
  }

  static int _nanoTime(DateTime dt) => dt.microsecondsSinceEpoch * 1000;
}
