import 'package:purple_otel_api/purple_otel_api.dart';

import '../context/zone_context_storage.dart';
import 'sdk_log_record.dart';

/// The flagship SDK implementation of [Logger].
///
/// Enriches incoming [LogRecord] instances with the active span context from
/// the configured [ContextStorage] and passes them to all registered
/// [LogRecordProcessor] instances.
final class SDKLogger implements Logger {
  final List<LogRecordProcessor> _processors;
  final Attributes _scopeAttributes;
  final ContextStorage _contextStorage;

  /// Creates an [SDKLogger].
  ///
  /// [name], [version], and [schemaUrl] identify the instrumentation scope.
  /// [processors] receive enriched log records on every [emit] call.
  /// [scopeAttributes] are merged into each record's attributes.
  /// [contextStorage] provides the active span context; defaults to [ZoneContextStorage].
  SDKLogger({
    required String name,
    String? version,
    String? schemaUrl,
    required List<LogRecordProcessor> processors,
    Attributes scopeAttributes = const Attributes.empty(),
    ContextStorage? contextStorage,
  })  : _processors = List.unmodifiable(processors),
        _scopeAttributes = scopeAttributes,
        _contextStorage = contextStorage ?? ZoneContextStorage();

  /// Emits a log record after enriching it with scope attributes and the active
  /// span context from [ContextStorage].
  ///
  /// If the incoming record does not carry trace context, the current span's
  /// [TraceId], [SpanId], and [TraceFlags] are attached automatically.
  @override
  void emit(LogRecord record) {
    final now = DateTime.now();
    final merged = record.attributes.merge(_scopeAttributes);
    final activeCtx = _contextStorage.current;
    final spanCtx = activeCtx.span?.spanContext;
    final enriched = SDKLogRecord(
      timestamp:
          record.timestamp == record.observedTimestamp ? now : record.timestamp,
      observedTimestamp: now,
      severityNumber: record.severityNumber,
      severityText: record.severityText,
      body: record.body,
      attributes: merged,
      traceId: record.traceId ?? spanCtx?.traceId,
      spanId: record.spanId ?? spanCtx?.spanId,
      traceFlags: record.traceFlags ?? spanCtx?.traceFlags,
    );

    for (final processor in _processors) {
      processor.onEmit(activeCtx, enriched);
    }
  }
}
