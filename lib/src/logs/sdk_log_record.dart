import 'package:purple_otel_api/purple_otel_api.dart';

/// The flagship SDK implementation of [LogRecord].
///
/// An immutable snapshot of a log event with optional trace context linking.
/// Use [SDKLogRecord.fromLogRecord] to copy and optionally enrich an existing
/// [LogRecord] instance.
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

  /// Creates an [SDKLogRecord].
  ///
  /// [severityText] is an optional human-readable severity label.
  /// [traceId], [spanId], and [traceFlags] link this record to a trace,
  /// enabling correlation with spans.
  /// [droppedAttributesCount] defaults to `0`.
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

  /// Creates an [SDKLogRecord] by copying all fields from an existing [record].
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
