import 'dart:async';
import 'dart:math';

import 'package:purple_otel_api/purple_otel_api.dart';

final class BatchConfig {
  final int maxQueueSize;
  final int maxExportBatchSize;
  final Duration scheduleDelay;

  const BatchConfig({
    this.maxQueueSize = 2048,
    this.maxExportBatchSize = 512,
    this.scheduleDelay = const Duration(seconds: 5),
  });
}

final class BatchLogRecordProcessor implements LogRecordProcessor {
  final LogRecordExporter _exporter;
  final BatchConfig _config;
  final List<LogRecord> _active = [];
  Timer? _flushTimer;
  bool _shutdown = false;
  int _droppedCount = 0;

  BatchLogRecordProcessor(this._exporter, {BatchConfig? config})
      : _config = config ?? const BatchConfig() {
    _flushTimer =
        Timer.periodic(_config.scheduleDelay, (_) => _scheduledFlush());
  }

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
    final batch = List<LogRecord>.of(_active.take(_config.maxExportBatchSize));
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
