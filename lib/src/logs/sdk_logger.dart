import 'package:purple_otel_api/purple_otel_api.dart';

import '../context/zone_context_storage.dart';
import 'sdk_log_record.dart';

final class SDKLogger implements Logger {
  final List<LogRecordProcessor> _processors;
  final Attributes _scopeAttributes;
  final ContextStorage _contextStorage;

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
