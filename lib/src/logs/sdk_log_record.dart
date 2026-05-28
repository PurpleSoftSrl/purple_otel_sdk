import 'package:purple_otel_api/purple_otel_api.dart';

final class SDKLogRecord implements LogRecord {
  @override
  final DateTime timestamp;
  @override
  final DateTime observedTimestamp;
  @override
  final Severity severityNumber;
  @override
  final String? severityText;
  @override
  final AttributeValue body;
  @override
  final Attributes attributes;
  @override
  final TraceId? traceId;
  @override
  final SpanId? spanId;
  @override
  final TraceFlags? traceFlags;
  @override
  final int droppedAttributesCount;

  const SDKLogRecord({
    required this.timestamp,
    required this.observedTimestamp,
    required this.severityNumber,
    this.severityText,
    required this.body,
    this.attributes = const Attributes.empty(),
    this.traceId,
    this.spanId,
    this.traceFlags,
    this.droppedAttributesCount = 0,
  });

  factory SDKLogRecord.fromLogRecord(LogRecord record) => SDKLogRecord(
        timestamp: record.timestamp,
        observedTimestamp: record.observedTimestamp,
        severityNumber: record.severityNumber,
        severityText: record.severityText,
        body: record.body,
        attributes: record.attributes,
        traceId: record.traceId,
        spanId: record.spanId,
        traceFlags: record.traceFlags,
        droppedAttributesCount: record.droppedAttributesCount,
      );
}
