import 'package:purple_otel_sdk/purple_otel_sdk.dart';
import 'package:test/test.dart';

final class _CaptureExporter implements LogRecordExporter {
  final List<LogRecord> exported = [];
  bool shutdownCalled = false;

  @override
  Future<ExportResult> export(List<LogRecord> items) async {
    exported.addAll(items);
    return ExportResult.success();
  }

  @override
  Future<void> shutdown() async {
    shutdownCalled = true;
  }

  @override
  Future<void> forceFlush() async {}
}

void main() {
  group('SDKLoggerProvider', () {
    test('get returns cached logger for same name', () {
      final exporter = _CaptureExporter();
      final provider = SDKLoggerProvider(
        resource: Resource.empty,
        processors: [SimpleLogRecordProcessor(exporter)],
      );
      final logger1 = provider.get('test');
      final logger2 = provider.get('test');
      expect(identical(logger1, logger2), isTrue);
    });

    test('get returns different loggers for different names', () {
      final exporter = _CaptureExporter();
      final provider = SDKLoggerProvider(
        resource: Resource.empty,
        processors: [SimpleLogRecordProcessor(exporter)],
      );
      final logger1 = provider.get('test1');
      final logger2 = provider.get('test2');
      expect(identical(logger1, logger2), isFalse);
    });

    test('shutdown clears loggers and shuts down exporter', () async {
      final exporter = _CaptureExporter();
      final provider = SDKLoggerProvider(
        resource: Resource.empty,
        processors: [SimpleLogRecordProcessor(exporter)],
      );
      provider.get('test');
      await provider.shutdown();
      expect(exporter.shutdownCalled, isTrue);
    });

    test('implements LoggerProvider interface', () {
      final exporter = _CaptureExporter();
      final provider = SDKLoggerProvider(
        resource: Resource.empty,
        processors: [SimpleLogRecordProcessor(exporter)],
      );
      expect(provider, isA<LoggerProvider>());
    });
  });

  group('SDKLogger', () {
    test('emit sends log record through processor chain to exporter', () {
      final exporter = _CaptureExporter();
      final processor = SimpleLogRecordProcessor(exporter);
      final logger = SDKLogger(
        name: 'test-logger',
        processors: [processor],
      );

      logger.emit(LogRecord(
        timestamp: DateTime(2024, 1, 1),
        observedTimestamp: DateTime(2024, 1, 1),
        severityNumber: Severity.info,
        body: AttributeValue.string('hello world'),
      ));

      expect(exporter.exported.length, 1);
      expect(exporter.exported.first.severityNumber, Severity.info);
    });

    test('emit enriches record with fresh observedTimestamp', () {
      final exporter = _CaptureExporter();
      final processor = SimpleLogRecordProcessor(exporter);
      final logger = SDKLogger(
        name: 'test-logger',
        processors: [processor],
      );

      logger.emit(LogRecord(
        timestamp: DateTime(2024),
        observedTimestamp: DateTime(2024),
        severityNumber: Severity.warn,
        body: AttributeValue.string('warning'),
      ));

      final exported = exporter.exported.first;
      expect(exported.observedTimestamp.isAfter(DateTime(2024)), isTrue);
    });

    test('emit merges scope attributes with record attributes', () {
      final exporter = _CaptureExporter();
      final processor = SimpleLogRecordProcessor(exporter);
      final logger = SDKLogger(
        name: 'test-logger',
        processors: [processor],
        scopeAttributes: Attributes.of({
          'scope.key': AttributeValue.string('scope-value'),
        }),
      );

      logger.emit(LogRecord(
        timestamp: DateTime(2024, 1, 1),
        observedTimestamp: DateTime(2024, 1, 1),
        severityNumber: Severity.info,
        body: AttributeValue.string('test'),
        attributes: Attributes.of({
          'user.key': AttributeValue.string('user-value'),
        }),
      ));

      final exported = exporter.exported.first;
      expect(exported.attributes.get('user.key'),
          AttributeValue.string('user-value'));
      expect(exported.attributes.get('scope.key'),
          AttributeValue.string('scope-value'));
    });
  });

  group('SimpleLogRecordProcessor', () {
    test('exports immediately on emit', () {
      final exporter = _CaptureExporter();
      final processor = SimpleLogRecordProcessor(exporter);

      processor.onEmit(Context.root, LogRecord(
        timestamp: DateTime.now(),
        observedTimestamp: DateTime.now(),
        severityNumber: Severity.error,
        body: AttributeValue.string('error!'),
      ));

      expect(exporter.exported.length, 1);
    });
  });

  group('BatchLogRecordProcessor', () {
    test('batches records and flushes at batch size', () async {
      final exporter = _CaptureExporter();
      final processor = BatchLogRecordProcessor(
        exporter,
        config: const BatchConfig(
          maxExportBatchSize: 2,
          maxQueueSize: 10,
          scheduleDelay: Duration(seconds: 60),
        ),
      );

      processor.onEmit(Context.root, LogRecord(
        timestamp: DateTime.now(), observedTimestamp: DateTime.now(),
        severityNumber: Severity.info, body: AttributeValue.string('msg1'),
      ));
      expect(exporter.exported.length, 0);

      processor.onEmit(Context.root, LogRecord(
        timestamp: DateTime.now(), observedTimestamp: DateTime.now(),
        severityNumber: Severity.info, body: AttributeValue.string('msg2'),
      ));
      expect(exporter.exported.length, 2);

      await processor.shutdown();
    });

    test('drops oldest when queue full', () async {
      final exporter = _CaptureExporter();
      final processor = BatchLogRecordProcessor(
        exporter,
        config: const BatchConfig(maxQueueSize: 2, maxExportBatchSize: 10,
            scheduleDelay: Duration(seconds: 60)),
      );

      processor.onEmit(Context.root, LogRecord(
        timestamp: DateTime.now(), observedTimestamp: DateTime.now(),
        severityNumber: Severity.info, body: AttributeValue.string('msg1'),
      ));
      processor.onEmit(Context.root, LogRecord(
        timestamp: DateTime.now(), observedTimestamp: DateTime.now(),
        severityNumber: Severity.info, body: AttributeValue.string('msg2'),
      ));
      processor.onEmit(Context.root, LogRecord(
        timestamp: DateTime.now(), observedTimestamp: DateTime.now(),
        severityNumber: Severity.info, body: AttributeValue.string('msg3'),
      ));

      expect(processor.droppedCount, 1);
      await processor.shutdown();
    });

    test('shutdown flushes remaining records', () async {
      final exporter = _CaptureExporter();
      final processor = BatchLogRecordProcessor(
        exporter,
        config: const BatchConfig(maxExportBatchSize: 10, maxQueueSize: 100,
            scheduleDelay: Duration(seconds: 60)),
      );

      processor.onEmit(Context.root, LogRecord(
        timestamp: DateTime.now(), observedTimestamp: DateTime.now(),
        severityNumber: Severity.info, body: AttributeValue.string('msg1'),
      ));

      await processor.shutdown();
      expect(exporter.exported.length, 1);
    });
  });

  group('ConsoleLogRecordExporter', () {
    test('export returns success for any items', () async {
      const exporter = ConsoleLogRecordExporter(pretty: false);
      final result = await exporter.export([
        LogRecord(
          timestamp: DateTime.now(), observedTimestamp: DateTime.now(),
          severityNumber: Severity.info, body: AttributeValue.string('test'),
        ),
      ]);
      expect(result.isSuccess, isTrue);
    });
  });

  group('SDKLogRecord', () {
    test('factory preserves all fields', () {
      final now = DateTime.now();
      final record = SDKLogRecord(
        timestamp: now,
        observedTimestamp: now,
        severityNumber: Severity.error,
        severityText: 'ERROR',
        body: AttributeValue.string('test'),
        attributes: Attributes.of({'key': AttributeValue.int(1)}),
      );
      expect(record.timestamp, now);
      expect(record.severityNumber, Severity.error);
      expect(record.severityText, 'ERROR');
    });
  });
}
