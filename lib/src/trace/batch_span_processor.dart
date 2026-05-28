import 'dart:async';
import 'dart:math';

import 'package:purple_otel_api/purple_otel_api.dart';
import '../logs/batch_log_record_processor.dart' show BatchConfig;

final class BatchSpanProcessor implements SpanProcessor {
  final SpanExporter _exporter;
  final BatchConfig _config;
  final List<Span> _active = [];
  Timer? _flushTimer;
  bool _shutdown = false;
  int _droppedCount = 0;

  BatchSpanProcessor(this._exporter, {BatchConfig? config})
      : _config = config ?? const BatchConfig() {
    _flushTimer = Timer.periodic(_config.scheduleDelay, (_) => _forceFlush());
  }

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
    final batch = List<Span>.of(_active.take(_config.maxExportBatchSize));
    _active.removeRange(0, min(batch.length, _active.length));
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
