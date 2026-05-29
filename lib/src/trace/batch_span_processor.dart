import 'dart:async';

import 'package:purple_otel_api/purple_otel_api.dart';
import '../logs/batch_log_record_processor.dart' show BatchConfig;

/// A [SpanProcessor] that batches spans and exports them on a periodic schedule
/// or when the batch size threshold is reached.
///
/// Spans are accumulated in an in-memory queue. When the queue reaches
/// [BatchConfig.maxExportBatchSize], a batch is exported immediately. A periodic
/// timer flushes remaining spans every [BatchConfig.scheduleDelay]. If the queue
/// exceeds [BatchConfig.maxQueueSize], the oldest spans are dropped and counted
/// in [droppedCount].
///
/// Default batch configuration: 2048 max queue, 512 max batch, 5-second schedule delay.
final class BatchSpanProcessor implements SpanProcessor {
  final SpanExporter _exporter;
  final BatchConfig _config;
  final List<Span> _active = [];
  Timer? _flushTimer;
  bool _shutdown = false;
  int _droppedCount = 0;

  /// Creates a [BatchSpanProcessor].
  ///
  /// [exporter] is the target backend for batched spans.
  /// [config] controls queue size, batch size, and flush interval; defaults
  /// to a [BatchConfig] with 2048 max queue, 512 max batch, 5-second delay.
  BatchSpanProcessor(this._exporter, {BatchConfig? config})
      : _config = (config ?? const BatchConfig()).validated() {
    _flushTimer = Timer.periodic(_config.scheduleDelay, (_) => _forceFlush());
  }

  /// The number of spans dropped due to a full queue.
  int get droppedCount => _droppedCount;

  @override
  bool get isStartRequired => false;

  @override
  bool get isEndRequired => true;

  @override
  void onStart(Context context, Span span) {}

  @override
  void onEnd(Span span) {
    if (_shutdown) return;
    if (_active.length >= _config.maxQueueSize) {
      _active.removeAt(0);
      _droppedCount++;
    }
    _active.add(span);
    if (_active.length >= _config.maxExportBatchSize) {
      _forceFlush();
    }
  }

  void _forceFlush() {
    if (_active.isEmpty) return;
    final take = _config.maxExportBatchSize;
    if (take == 0) return;
    final batch = List<Span>.of(_active.take(take));
    _active.removeRange(0, batch.length);
    _exporter.export(batch);
  }

  @override
  Future<void> forceFlush() async {
    _forceFlush();
  }

  @override
  Future<void> shutdown() async {
    _shutdown = true;
    _flushTimer?.cancel();
    while (_active.isNotEmpty) {
      _forceFlush();
    }
    await _exporter.shutdown();
  }
}
