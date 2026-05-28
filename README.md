# PurpleOTel SDK

[![Pub Version](https://img.shields.io/pub/v/purple_otel_sdk.svg)](https://pub.dev/packages/purple_otel_sdk)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Dart](https://img.shields.io/badge/dart-%3E%3D3.2.0-blue.svg)](https://dart.dev)

The complete OpenTelemetry SDK for Dart and Flutter — traces, logs, metrics, OTLP export, W3C propagation, and distributed context.

**Zero global state. Dependency injection everywhere. Manual protobuf encoder (zero `.pb.dart` files in production).**

## Features

### Traces
- `SDKTracerProvider` / `SDKTracer` / `SDKSpan` — full trace lifecycle
- **Samplers**: AlwaysOn, AlwaysOff, ParentBased, TraceIdRatioBased
- **SpanLimits** enforcement — max attributes, events, links, attribute value length
- **W3C TraceContext** propagation — inject/extract via HTTP headers
- **RandomIdGenerator** — secure random TraceId/SpanId generation
- **Lazy allocation** — attributes, events, and links maps only allocated on first use

### Logs
- `SDKLoggerProvider` / `SDKLogger` / `SDKLogRecord` — structured log pipeline
- **Severity mapping** — all 24 OTel severity levels (TRACE through FATAL4)
- **Scope attributes** — auto-merged into every emitted LogRecord
- **Automatic trace correlation** — LogRecords inherit traceId/spanId from active context

### Metrics
- **Synchronous instruments**: Counter, UpDownCounter, DoubleHistogram, LongHistogram
- **Observable instruments**: Gauge, Counter, UpDownCounter (async callbacks)
- **Aggregations**: Sum, LastValue, ExplicitBucketHistogram with Int64List storage
- **Delta & Cumulative temporality** — configurable per-reader
- **CardinalityController** — configurable max attribute combinations with overflow handling
- **View API** — instrument selection, attribute filtering, aggregation override

### Exporters
- **OTLP HTTP** (protobuf) — logs, traces, and metrics to any OTel collector
- **Console** — human-readable output for development and debugging
- **Manual protobuf encoder** — zero generated `.pb.dart` files (500 lines vs 75+ files in other SDKs)

### Context
- **ZoneContextStorage** — zone-based async context propagation
- **`runWithContext()`** — explicit context scoping for distributed tracing
- **`spanContextKey` / `baggageContextKey`** — typed ContextKey constants

### Processors
- **SimpleSpanProcessor / SimpleLogRecordProcessor** — immediate export
- **BatchSpanProcessor / BatchLogRecordProcessor** — buffered with configurable batch size, queue size, and flush interval
- **Retry with exponential backoff** — built into OTLP HTTP client
- **Drop counting** — oldest-eviction with `droppedCount` metric when queue is full

## Quick Start

```dart
import 'package:purple_otel_sdk/purple_otel_sdk.dart';

void main() async {
  // 1. Create the SDK
  final sdk = SDKTracerProvider(
    resource: Resource(Attributes.fromMap({
      'service.name': 'my-api',
      'service.version': '1.0.0',
      'deployment.environment': 'production',
    })),
    processors: [
      BatchSpanProcessor(
        OtlpHttpSpanExporter(
          endpoint: Uri.parse('https://collector.example.com:4318'),
        ),
      ),
    ],
  );

  // 2. Get a tracer
  final tracer = sdk.get('order-service');

  // 3. Create spans
  final span = tracer.startSpan('process-order', kind: SpanKind.server);
  span.setAttribute('order.id', AttributeValue.string('42'));
  span.setAttribute('order.total', AttributeValue.double(99.99));
  span.setStatus(SpanStatus.ok);
  span.end();

  // 4. Shutdown (flushes remaining spans)
  await sdk.shutdown();
}
```

## Distributed Tracing

```dart
final tracer = sdk.get('api-gateway');

// Parent span
final parent = tracer.startSpan('handle-request', kind: SpanKind.server);

// Propagate context to child operations
ZoneContextStorage.runWithContext(
  Context.root.withValue(spanContextKey, parent),
  () {
    // Child span inherits traceId from parent
    final child = tracer.startSpan('fetch-user', kind: SpanKind.client);
    child.setAttribute('user.id', AttributeValue.string('42'));
    child.end();
  },
);

parent.end();
```

## OTLP Export

```dart
final exporter = OtlpHttpSpanExporter(
  endpoint: Uri.parse('https://collector:4318'),
  headers: {'x-api-key': 'your-key'},
);

final processor = BatchSpanProcessor(
  exporter,
  config: const BatchConfig(
    maxQueueSize: 2048,
    maxExportBatchSize: 512,
    scheduleDelay: Duration(seconds: 5),
  ),
);
```

## Metrics Example

```dart
final meterProvider = SDKMeterProvider(
  resource: Resource.empty,
  readers: [
    PeriodicExportingMetricReader(
      exporter: OtlpHttpMetricExporter(endpoint: Uri.parse('https://collector:4318')),
      interval: Duration(seconds: 60),
      temporality: Temporality.delta,
    ),
  ],
);

final meter = meterProvider.get('api-service');
final counter = meter.createCounter('http.requests');
counter.add(1, attributes: Attributes.of({'status': AttributeValue.int(200)}));

final hist = meter.createDoubleHistogram('http.duration');
hist.record(42.5, attributes: Attributes.of({'method': AttributeValue.string('GET')}));
```

## Architecture

```
purple_otel_sdk/
├── lib/
│   ├── purple_otel_sdk.dart         # Barrel
│   └── src/
│       ├── trace/                   # TracerProvider, Tracer, Span, Samplers, Processors
│       ├── logs/                    # LoggerProvider, Logger, LogRecord, Processors
│       ├── metrics/                 # MeterProvider, Meter, Instruments, Aggregations, Reader
│       ├── otlp/                    # Manual protobuf encoder (common, trace, logs, metrics)
│       ├── export/                  # OTLP HTTP exporters + console exporters
│       ├── propagation/             # W3C TraceContext propagator
│       └── context/                 # ZoneContextStorage, runWithContext
```

## Companion Packages

| Package | Description |
|---------|-------------|
| [purple_otel_api](https://pub.dev/packages/purple_otel_api) | API interfaces (zero deps) |
| [purple_otel_http](https://pub.dev/packages/purple_otel_http) | Auto-instrumentation for package:http |
| [purple_otel_dio](https://pub.dev/packages/purple_otel_dio) | Auto-instrumentation for Dio |
| [purple_otel_flutter](https://pub.dev/packages/purple_otel_flutter) | Flutter integration (NavigatorObserver, lifecycle) |

## Performance

- **Manual protobuf encoder** — ~500 lines producing identical OTLP wire format, zero code generation
- **Lazy map allocation** — Span attributes/events/links allocated only on first `setAttribute`/`addEvent`/`addLink`
- **Int64List histogram buckets** — zero object overhead for bucket counts
- **Instrument caching** — Tracer/Logger/Meter instances cached by (name, version, schemaUrl)
- **Shared OTLP HTTP client** — one connection pool for all signal exporters

## License

Apache-2.0 — see [LICENSE](LICENSE).
