// PurpleOTel SDK — Quick Start Example
// This example demonstrates the core features of purple_otel_sdk:
// traces, logs, metrics, OTLP export, and W3C propagation.
//
// Run: dart run example/main.dart

import 'package:purple_otel_sdk/purple_otel_sdk.dart';

void main() async {
  // 1. Create resource identifying your service
  final resource = Resource(Attributes.fromMap({
    'service.name': 'purple-otel-example',
    'service.version': '1.0.0',
  }));

  // 2. Create tracer with console export (for demo)
  final tracerProvider = SDKTracerProvider(
    resource: resource,
    processors: [SimpleSpanProcessor(const ConsoleSpanExporter())],
    sampler: const AlwaysOnSampler(),
  );

  final tracer = tracerProvider.get('example-app');

  // 3. Create a span with attributes and events
  final span = tracer.startSpan('process-order', kind: SpanKind.server);
  span.setAttribute('order.id', AttributeValue.string('ord-42'));
  span.setAttribute('order.total', AttributeValue.double(99.99));
  span.addEvent('payment.processed');

  try {
    // Simulate work
    await Future.delayed(const Duration(milliseconds: 10));
    span.setStatus(SpanStatus.ok);
  } catch (e, st) {
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatus.error('Order processing failed'));
  }
  span.end();

  // 4. W3C TraceContext — inject into headers
  final ctx = Context.root.withValue(spanContextKey, span);
  final headers = <String, String>{};
  W3CTraceContextPropagator.inject(ctx, headers);
  print('traceparent: ${headers['traceparent']}');

  // 5. Create a logger with automatic trace correlation
  final logProvider = SDKLoggerProvider(
    resource: resource,
    processors: [SimpleLogRecordProcessor(const ConsoleLogRecordExporter())],
  );
  final logger = logProvider.get('example-app');
  logger.emit(LogRecord(
    timestamp: DateTime.now(),
    observedTimestamp: DateTime.now(),
    severityNumber: Severity.info,
    body: AttributeValue.string('Order processed successfully'),
    attributes: Attributes.of({'order.id': AttributeValue.string('ord-42')}),
  ));

  // 6. Metrics — create a counter
  final meterProvider = SDKMeterProvider(
    resource: Resource.empty,
    readers: [],
  );
  final meter = meterProvider.get('example-app');
  final counter = meter.createCounter('orders.processed');
  counter.add(1);

  // 7. Shutdown
  await tracerProvider.shutdown();
  await logProvider.shutdown();
  print('Example completed successfully.');
}
