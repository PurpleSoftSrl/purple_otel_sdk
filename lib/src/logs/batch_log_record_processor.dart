import 'dart:async';
import 'dart:math';

import 'package:purple_otel_api/purple_otel_api.dart';

/// Configuration for batch processors controlling queue size, batch size, and
/// flush interval.
///
/// Used by both [BatchLogRecordProcessor] and [BatchSpanProcessor].
///
/// Default values: 2048 max queue, 512 max batch, 5-second schedule delay.
final class BatchConfig {
  /// Maximum number of items allowed in the queue before old items are dropped.
  final int maxQueueSize;

  /// Maximum number of items to export in a single batch.
  final int maxExportBatchSize;

  /// Interval between scheduled flushes of the queue.
  final Duration scheduleDelay;

  /// Creates a [BatchConfig].
  const BatchConfig({
    this.maxQueueSize = 2048,
    this.maxExportBatchSize = 512,
    this.scheduleDelay = const Duration(seconds: 5),
  });

  /// Returns a copy of this config with values clamped to a minimum of `1`.
  BatchConfig validated() {
    return BatchConfig(
      maxQueueSize: maxQueueSize < 1 ? 1 : maxQueueSize,
      maxExportBatchSize: maxExportBatchSize < 1 ? 1 : maxExportBatchSize,
      scheduleDelay: scheduleDelay,
    );
  }
}

/// A [LogRecordProcessor] that batches log records and exports them on a
/// periodic schedule or when the batch size threshold is reached.
///
/// Records are accumulated in an in-memory queue. When the queue reaches
/// [BatchConfig.maxExportBatchSize], a batch is exported immediately. A periodic
/// timer flushes remaining records every [BatchConfig.scheduleDelay]. If the
/// queue exceeds [BatchConfig.maxQueueSize], the oldest records are dropped and
/// counted in [droppedCount].
///
/// Default batch configuration: 2048 max queue, 512 max batch, 5-second schedule delay.
final class BatchLogRecordProcessor implements LogRecordProcessor {
  final LogRecordExporter _exporter;
  final BatchConfig _config;
  final List<LogRecord> _active = [];
  Timer? _flushTimer;
  bool _shutdown = false;
  int _droppedCount = 0;

  /// Creates a [BatchLogRecordProcessor].
  ///
  /// [exporter] is the target backend for batched records.
  /// [config] controls queue size, batch size, and flush interval; defaults
  /// to a [BatchConfig] with 2048 max queue, 512 max batch, 5-second delay.
  BatchLogRecordProcessor(this._exporter, {BatchConfig? config})
      : _config = (config ?? const BatchConfig()).validated() {
    _flushTimer = Timer.periodic(_config.scheduleDelay, (_) => _scheduledFlush());
  }

  /// The number of records dropped due to a full queue.
  int get droppedCount => _droppedCount;

  @override
  void onEmit(Context context, LogRecord record) {
    if (_shutdown) return;
    if (_active.length >= _config.maxQueueSize) {
      _active.removeAt(0);
      _droppedCount++;
    }
    _active.add(record);
    if (_active.length >= _config.maxExportBatchSize) {
      _flush();
    }
  }

  void _scheduledFlush() {
    _flush();
  }

  void _flush() {
    if (_active.isEmpty) return;
    final take = _config.maxExportBatchSize;
    if (take == 0) return;
    final batch = List<LogRecord>.of(_active.take(take));
    _active.removeRange(0, min(batch.length, _active.length));
    _exporter.export(batch);
  }

  @override
  Future<void> forceFlush() async {
    _flush();
  }

  @override
  Future<void> shutdown() async {
    _shutdown = true;
    _flushTimer?.cancel();
    while (_active.isNotEmpty) {
      _flush();
    }
    await _exporter.shutdown();
  }
}
