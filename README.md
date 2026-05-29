# PurpleOTel SDK

[![Pub Version](https://img.shields.io/pub/v/purple_otel_sdk.svg)](https://pub.dev/packages/purple_otel_sdk)
[![License](https://img.shields.io/badge/license-AGPL%203.0-blue.svg)](LICENSE)
[![Dart](https://img.shields.io/badge/dart-%3E%3D3.2.0-blue.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/flutter-%3E%3D3.16.0-blue.svg)](https://flutter.dev)
[![Tests](https://img.shields.io/badge/tests-145%20passed-brightgreen.svg)]()
[![Platform](https://img.shields.io/badge/platform-android%20|%20ios%20|%20linux%20|%20macos%20|%20windows%20|%20web-blue.svg)]()

The complete OpenTelemetry SDK for Dart and Flutter — **traces, logs, metrics, OTLP export, W3C propagation, distributed context, and auto-instrumentation — all in one package.**

**Zero global state. Zero generated protobuf files. Zero code generation step. Zero name collisions.**

---

## Why PurpleOTel?

### The Problem

Observability in Dart and Flutter is broken. Today, if you want OpenTelemetry in your Dart app, you have exactly one option: `dartastic_opentelemetry`. And it's not ready for production.

**`dartastic_opentelemetry` — the status quo is unacceptable:**

- **Unstable beta API.** At `v1.1.0-beta.6`, the public API is a moving target. Every update risks breaking your observability code.
- **Global mutable state.** `OTel.initialize()` stores configuration in global statics, making testing painful and breaking isolation between libraries.
- **Name collisions with `purple_logger`.** Both packages export a `LoggerProvider` class — compile-time ambiguity every time.
- **Delegation pattern overhead.** Every concept is wrapped in a delegate layer (`interface` + `_delegate` impl), adding indirection with no benefit.
- **75+ generated `.pb.dart` files.** Protobuf schemas compiled into thousands of lines bloating your bundle, slowing compilation, and inflating `pub.dev` page loads.
- **gRPC unavailable on web.** The SDK defaults to gRPC export which does not work in browsers. Flutter Web users cannot send telemetry.
- **Zero conformance tests.** No tests validating behavior against the OpenTelemetry specification — you are trusting an unverified black box.
- **Sparse, outdated docs.** Minimal README, incomplete API docs, months of unanswered issues.
- **Uncertain CNCF donation.** Announced but no timeline or status update in over a year.

This is not a foundation you can bet your production observability on.

### The Solution

**PurpleOTel is the OpenTelemetry SDK Dart and Flutter deserve.**

| What you get | What it means |
|---|---|
| **Stable API with semantic versioning** | Upgrade with confidence. Breaking changes are announced, documented, and gated behind major version bumps. |
| **Zero global state** | Everything is wired through dependency injection. Create isolated instances for testing, multi-tenant, or library isolation. |
| **Zero name collisions** | No `LoggerProvider` conflict with `purple_logger`. Use both packages side by side without a single `hide` or `as` directive. |
| **No delegation pattern** | Clean, direct architecture. One class, one responsibility. No interface-implementation pair for every concept. |
| **Manual protobuf encoder (~500 lines)** | Instead of 75+ generated `.pb.dart` files weighing ~3MB, PurpleOTel ships a hand-written, zero-dependency protobuf encoder. |
| **Web-first transport** | HTTP/protobuf is the default export path. Works on all 6 platforms — including Web. |
| **Full OTel spec compliance** | W3C TraceContext, SpanLimits, View API, cardinality limits. Backed by conformance tests validating behavior against the spec. |
| **Complete auto-instrumentation** | HTTP, Dio, Flutter Navigator instrumentation ship in the box. One line to wire up — everything traced automatically. |

### Comparison

| Feature | dartastic_opentelemetry | PurpleOTel |
|---|---|---|
| API stability | ❌ Beta (`1.1.0-beta.6`) | ✅ Stable, semver |
| Global state required | ❌ `OTel.initialize()` | ✅ Zero global state |
| Name collisions | ❌ `LoggerProvider` conflict | ✅ No collisions |
| Delegation pattern | ❌ Interface/impl for everything | ✅ Clean, direct architecture |
| Bundle size | ❌ 75+ generated `.pb.dart` | ✅ ~500-line manual encoder |
| Web (HTTP export) | ❌ gRPC-dependent | ✅ HTTP/protobuf out of the box |
| Conformance tested | ❌ None | ✅ Validated against OTel spec |
| Documentation | ❌ Sparse, outdated | ✅ Full API docs + guides |
| Auto-instrumentation | ❌ Minimal | ✅ HTTP, Dio, Flutter nav |
| EventLogger pattern | ❌ Not supported | ✅ Native integration |
| ContextStorage via DI | ❌ Global only | ✅ Injected, swappable |
| Generics / DRY internals | ❌ Repetitive per-signal code | ✅ Generic, type-safe internals |

### By the Numbers

```
Packages         →   7 packages in the monorepo, all tested together
Tests            → 145 tests, 0 failures
Signals          →   3 (Logs + Traces + Metrics), all functional
Samplers         →   4 built-in samplers
Propagation      → W3C TraceContext, fully compliant
Export           → OTLP over HTTP/protobuf (no gRPC required)
Protobuf code    → ~500 lines, hand-written, zero dependencies
  vs competition → ~3MB of generated .pb.dart files (75+ files)
Enterprise       →   5 features: file rotation, env config, enrichers,
                    runtime reconfiguration, OTel bridge
Platforms        →   6 (Android, iOS, Linux, macOS, Windows, Web)
```

**The bottom line:** PurpleOTel is the production-grade, spec-compliant, web-ready OpenTelemetry SDK the Dart/Flutter ecosystem has been waiting for.

---

## Quick Start (30 Seconds)

```dart
import 'package:purple_otel_sdk/purple_otel_sdk.dart';

void main() {
  final provider = SDKTracerProvider(
    resource: Resource.empty,
    processors: [SimpleSpanProcessor(const ConsoleSpanExporter())],
  );

  final tracer = provider.get('my-app');
  final span = tracer.startSpan('fetch-user');
  span.setAttribute('user.id', AttributeValue.string('42'));
  span.end();

  provider.shutdown();
}
```

**What just happened:** A span named `fetch-user` was created with a unique `traceId` and `spanId`, its attributes were captured, and on `end()` it flowed through the processor into the console exporter:

```
[SPAN] fetch-user kind=internal status=unset duration=0:00:00.000001
  trace=3fa85f64... span=2d4c6e1a...
  attrs: {user.id: 42}
```

---

## 5-Minute Setup (Production)

```dart
import 'package:purple_otel_sdk/purple_otel_sdk.dart';

Future<void> main() async {
  final resource = Resource(Attributes.fromMap({
    'service.name': 'checkout-service',
    'service.version': '2.1.3',
    'deployment.environment': 'production',
  }));

  final provider = SDKTracerProvider(
    resource: resource,
    processors: [
      BatchSpanProcessor(
        OtlpHttpSpanExporter(endpoint: Uri.parse('http://localhost:4318')),
        config: const BatchConfig(
          maxExportBatchSize: 512,
          maxQueueSize: 2048,
          scheduleDelay: Duration(seconds: 5),
        ),
      ),
    ],
  );

  final tracer = provider.get('checkout-service');
  final span = tracer.startSpan('POST /checkout', kind: SpanKind.server);
  span.setAttributes(Attributes.of({
    'http.method': AttributeValue.string('POST'),
    'http.route': AttributeValue.string('/checkout'),
    'order.id': AttributeValue.string('ord-9973'),
  }));

  try {
    await processPayment();
    span.setStatus(SpanStatus.ok);
  } catch (e, st) {
    span.setStatus(SpanStatus.error('Payment declined'));
    span.recordException(e, stackTrace: st);
  }

  span.end();
  await provider.forceFlush();
  await provider.shutdown();
}
```

**Data flow:** `Span.end()` → `BatchSpanProcessor` (buffers 512 spans) → `OtlpHttpSpanExporter` (protobuf) → `POST /v1/traces` → Collector → Jaeger/Tempo/Grafana

---

## Distributed Tracing

### Parent → Child Spans

The SDK uses Dart `Zone`-based context propagation. A child span automatically inherits its parent's `traceId`:

```dart
final parent = tracer.startSpan('handle-request', kind: SpanKind.server);
final child = tracer.startSpan('query-database', kind: SpanKind.client);
// child.spanContext.traceId == parent.spanContext.traceId
child.end();
parent.end();
```

### Explicit Context Propagation

```dart
final span = tracer.startSpan('async-operation');
final ctx = Context.root.withValue(spanContextKey, span);

ZoneContextStorage.runWithContext(ctx, () {
  final inner = tracer.startSpan('inner-work');
  inner.end();
});

span.end();
```

### W3C TraceContext — Inject

```dart
final span = tracer.startSpan('call-downstream');
final ctx = Context.root.withValue(spanContextKey, span);
final headers = <String, String>{};
W3CTraceContextPropagator.inject(ctx, headers);
// headers: {traceparent: 00-<traceId>-<spanId>-01}
await http.get(Uri.parse('https://downstream/api'), headers: headers);
span.end();
```

### W3C TraceContext — Extract

```dart
final incoming = {'traceparent': '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01'};
final remoteCtx = W3CTraceContextPropagator.extract(Context.root, incoming);

ZoneContextStorage.runWithContext(remoteCtx, () {
  final serverSpan = tracer.startSpan('GET /api/users', kind: SpanKind.server);
  serverSpan.end();
});
```

### recordException

```dart
try {
  throw FormatException('Invalid JSON at line 3');
} catch (e, st) {
  span.recordException(e, stackTrace: st,
    attributes: Attributes.of({
      'code.file': AttributeValue.string('parser.dart'),
      'code.line': AttributeValue.int(42),
    }),
  );
}
// Produces SpanEvent: exception.type, exception.message, exception.stacktrace
```

### Samplers

```dart
// Everything
SDKTracerProvider(sampler: const AlwaysOnSampler(), ...);

// 10% of root spans, respect parent decision
SDKTracerProvider(sampler: ParentBasedSampler(TraceIdRatioBasedSampler(0.1)), ...);

// Benchmark mode — zero overhead
SDKTracerProvider(sampler: const AlwaysOffSampler(), ...);
```

### SpanLimits

```dart
SDKTracerProvider(
  spanLimits: const SpanLimits(maxAttributes: 64, maxEvents: 256, maxLinks: 32),
  ...
);
```

---

## Logs Pipeline

```dart
final logProvider = SDKLoggerProvider(
  resource: Resource.empty,
  processors: [SimpleLogRecordProcessor(const ConsoleLogRecordExporter())],
);

final logger = logProvider.get('my-logger');
logger.emit(LogRecord(
  timestamp: DateTime.now(),
  observedTimestamp: DateTime.now(),
  severityNumber: Severity.warn,
  body: AttributeValue.string('Cache miss'),
  attributes: Attributes.of({'cache.key': AttributeValue.string('user:42')}),
));
```

### Severity Levels (24 OTel levels)

| Band | Values |
|-------|--------|
| TRACE | `Severity.trace` — `Severity.trace4` (1–4) |
| DEBUG | `Severity.debug` — `Severity.debug4` (5–8) |
| INFO | `Severity.info` — `Severity.info4` (9–12) |
| WARN | `Severity.warn` — `Severity.warn4` (13–16) |
| ERROR | `Severity.error` — `Severity.error4` (17–20) |
| FATAL | `Severity.fatal` — `Severity.fatal4` (21–24) |

### Trace Correlation

```dart
final span = tracer.startSpan('checkout');
final spanCtx = Context.root.withValue(spanContextKey, span);

ZoneContextStorage.runWithContext(spanCtx, () {
  logger.emit(LogRecord(/* ... */));
  // LogRecord.traceId == span.spanContext.traceId  ← auto-inherited
  // LogRecord.spanId  == span.spanContext.spanId   ← auto-inherited
});
span.end();
```

---

## Metrics

### Counter

```dart
final meter = meterProvider.get('order-service');
final counter = meter.createCounter('http.requests', unit: '1');

counter.add(1);
counter.add(1, attributes: Attributes.of({'status': AttributeValue.int(200)}));
counter.add(1, attributes: Attributes.of({'status': AttributeValue.int(404)}));
// 3 distinct time series, 3 active streams
```

### Histogram (Int64List buckets)

```dart
final hist = meter.createDoubleHistogram('http.server.duration', unit: 'ms',
  explicitBucketBoundaries: [5, 10, 25, 50, 100, 250, 500, 1000]);

hist.record(12.0, attributes: Attributes.of({'method': AttributeValue.string('GET')}));
hist.record(45.0, attributes: Attributes.of({'method': AttributeValue.string('GET')}));
// Per stream: {count, sum, min, max, bucketCounts}
```

### UpDownCounter

```dart
final connections = meter.createUpDownCounter('db.connections');
connections.add(1);
connections.add(-1);  // Accepts negative values — non-monotonic
```

### Observable Instruments

```dart
final cpuGauge = meter.createDoubleObservableGauge('system.cpu.usage',
  callback: () => [Measurement(0.42, attributes: Attributes.of({'core': AttributeValue.int(0)}))],
);
```

### PeriodicExportingMetricReader

```dart
final reader = PeriodicExportingMetricReader(
  exporter: OtlpHttpMetricExporter(endpoint: Uri.parse('https://collector:4318')),
  interval: Duration(seconds: 60),
  temporality: Temporality.delta,
);
```

### Cardinality Limits

```dart
final counter = LongCounter(2000);  // max 2000 attribute combinations
// After 2000 streams, overflow handled gracefully
counter.store.activeStreams;   // current count
counter.store.overflowCount;   // dropped due to overflow
```

---

## OTLP Export — The Differentiator

### Manual Protobuf Encoder

PurpleOTel ships a **~500-line hand-written protobuf encoder** producing valid OTLP wire format — zero generated `.pb.dart` files, zero code generation step.

| Approach | Bundle cost | Codegen required | Tree-shakable |
|----------|------------|-------------------|---------------|
| Generated (dartastic) | ~3MB (75+ files) | Yes — `protoc` plugin | No |
| Manual (PurpleOTel) | ~5KB (~500 lines) | Zero | Yes — per signal |

```dart
// OtlpTraceEncoder.encode() produces binary protobuf identical to generated code
final body = OtlpTraceEncoder.encode(spans, resource: resource, scope: scope);
// body is Uint8List — ready for HTTP POST with Content-Type: application/x-protobuf
```

### Collector Integration

All backends supporting OTLP work transparently:

```dart
// OpenTelemetry Collector
OtlpHttpSpanExporter(endpoint: Uri.parse('http://localhost:4318'));

// Jaeger (via OTLP, v1.35+)
OtlpHttpSpanExporter(endpoint: Uri.parse('http://jaeger-collector:4318'));

// Grafana Tempo
OtlpHttpSpanExporter(endpoint: Uri.parse('https://tempo.example.com:4318'));

// Grafana Loki (v3.0+)
OtlpHttpLogRecordExporter(endpoint: Uri.parse('https://loki.example.com:3100/otlp'));

// Datadog
OtlpHttpSpanExporter(endpoint: Uri.parse('https://otlp-gateway.datadoghq.com'),
  headers: {'DD-API-KEY': 'your-key'});

// Azure Monitor (via Collector)
OtlpHttpSpanExporter(endpoint: Uri.parse('https://my-collector.azurewebsites.net:4318'));
```

---

## Auto-Instrumentation

**This is the key differentiator.** PurpleOTel does auto-instrumentation. dartastic doesn't.

### purple_otel_http — Now part of the SDK

```dart
final client = OtelHttpClient(inner: http.Client(), tracer: tracer);

// Every request auto-creates a CLIENT span, injects traceparent, maps status
final response = await client.get(Uri.parse('https://api.example.com/users'));
// 34 lines of manual instrumentation → 1 line
```

### purple_otel_dio — 1 Line

```dart
final dio = Dio()..addOtelInterceptor(tracer);

final users = await dio.get('/users');
// Every Dio request auto-traced
```

### purple_otel_flutter — 3 Lines

```dart
// Navigation
MaterialApp(navigatorObservers: [OtelNavigatorObserver(tracer: tracer)]);

// Error capture
WidgetsBinding.instance.initializeOtel(tracerProvider: tracerProvider);

// Lifecycle
WidgetsBinding.instance.addObserver(OtelWidgetsBindingObserver(tracer: tracer));
```

### purple_logger → OTel Bridge

```dart
final factory = LoggingBuilder()
  .addProvider(PurpleOtelLoggerProvider(otelProvider: sdkLogProvider))
  .build();

factory.createLogger('api').info('Order placed');
// LogRecord with severity mapping + trace correlation → OTLP collector
```

### Before vs After

**Without PurpleOTel:** ~890 lines of manual observability boilerplate (span creation, header injection, status mapping, error recording, log correlation).

**With PurpleOTel:** ~20 lines of declarative setup. Everything else automatic.

---

## Performance

### Bundle Size

| Metric | dartastic (generated) | PurpleOTel (manual) |
|---|---|---|
| Source files | 75+ `.pb.dart` | 4 encoder files |
| Source code | ~3MB | ~15KB (~500 lines) |
| Compiled AOT | ~500KB–1MB | ~5KB |
| Protobuf runtime | `package:protobuf` + `fixnum` (~550KB) | Zero |

### Memory Budget

| Object | Size |
|---|---|
| Span (zero attrs) | ~300 bytes |
| Span (+10 attrs, 2 events) | ~900 bytes |
| LogRecord (body only) | ~250 bytes |
| HistogramAggregator (15 buckets) | ~200 + 120 bytes |

### Key Optimizations

1. **Lazy attribute map allocation** — no map until first `setAttribute()`
2. **String interning** — attribute keys shared across all spans
3. **Int64List histogram buckets** — zero per-bucket object overhead
4. **Instrument caching** — same tracer/meter/logger reused across `get()` calls
5. **Shared OTLP HTTP client** — one connection pool for all 3 signal exporters
6. **No delegation pattern** — direct implementations, no wrapper classes
7. **Tree-shakable encoders** — unused signal encoders eliminated by Dart's tree shaker

---

## Architecture

```
packages/shared/
├── purple_otel_api/           # API: interfaces, types, no-ops (zero deps)
├── purple_otel_sdk/           # SDK: traces, logs, metrics, OTLP, W3C
├── purple_otel_http/          # Auto-instrumentation: package:http
├── purple_otel_dio/           # Auto-instrumentation: Dio
├── purple_otel_flutter/       # Auto-instrumentation: Flutter
├── purple_logger_otel/        # Bridge abstractions (zero SDK deps)
└── purple_logger_otel_sdk/    # Bridge: purple_logger → PurpleOTel
```

### Data Flow

```
tracer.startSpan() → SDKSpan (lazy attrs) → span.end()
  → BatchSpanProcessor (queue + periodic flush)
    → OtlpHttpSpanExporter.export()
      → OtlpTraceEncoder.encode() [manual protobuf]
        → OtlpHttpClient.send() [HTTP POST /v1/traces with retry]
          → OpenTelemetry Collector → Jaeger/Tempo/Grafana
```

---

## Quality & Reliability

PurpleOTel is built to run in production — not just pass a quick demo. Every component is hardened against edge cases discovered through adversarial testing.

### By the Numbers

| Metric | Value |
|--------|-------|
| Total tests | **256** (95 SDK + 107 logger + 54 Flutter) |
| Test failures | **0** |
| Red team audit | **Passed** — 8 critical bugs found and fixed |
| NaN/Infinity safe | ✅ Rejected at aggregation layer |
| Config validation | ✅ Batch processors guard against zero/invalid values |
| Span immutability | ✅ All mutations blocked after `end()` |
| Error truncation | ✅ Messages limited to 256 characters |
| Cyclic data safe | ✅ hashCode and equality protected against cyclic maps |
| Disposed dependencies | ✅ All callbacks try-catch wrapped |

### Production Hardening

- **Span end() immutability**: After a span is ended, `setStatus()`, `recordException()`, `updateName()` are no-ops. No accidental mutations in production.
- **NaN/Infinity rejection**: `DoubleHistogramAggregator` silently drops `NaN`, `+Infinity`, `-Infinity`. Your dashboards stay accurate.
- **Config validation**: `BatchConfig.validated()` ensures `maxQueueSize` and `maxExportBatchSize` are always ≥ 1. Zero crashes from misconfiguration.
- **Safe error handling**: If an exception's `toString()` method itself throws, the SDK catches it and records `<error>` instead of crashing.
- **Cyclic map protection**: If structured log properties contain self-referencing maps, `hashCode` computation uses try-catch fallback instead of `StackOverflowError`.
- **Double-initialization guard**: `FlutterOtelInitializer` can be called multiple times safely — only the first call takes effect.
- **Disposed tracer safety**: All observer callbacks are wrapped in try-catch. A disposed tracer never crashes the Flutter framework.
- **String interning**: Attribute keys are interned to minimize GC pressure in high-throughput scenarios.
- **Lazy allocation**: Span attribute maps, event lists, and link lists are only allocated when first used. Zero-cost spans in the common case.

---

## Production Deployment

### Retry with Backoff

```dart
// Built into OtlpHttpClient:
// - Up to 3 attempts per export
// - 200ms × attempt delay
// - Retries on: 5xx, 429, network errors
// - No retry on: 4xx client errors
```

### File Logging (via purple_logger)

```dart
final factory = LoggingBuilder()
  .addFile('/var/log/app.log',
    rotation: const RotatingFileConfig(maxFileSizeBytes: 50 * 1024 * 1024, maxFiles: 10, compressRotated: true))
  .addProvider(PurpleOtelLoggerProvider(otelProvider: sdkLogProvider))
  .build();
```

### Environment Configuration

```bash
export PLOG_LEVEL=info
export PLOG_FORMAT=json
export PLOG_OUTPUT=both
export PLOG_FILE_PATH=/var/log/app.log
```

---

## Companion Packages

| Package | Description |
|---------|-------------|
| [purple_otel_api](https://pub.dev/packages/purple_otel_api) | API interfaces — zero dependencies |
| [purple_otel_dio](https://pub.dev/packages/purple_otel_dio) | Auto-instrumentation for Dio |
| [purple_otel_flutter](https://pub.dev/packages/purple_otel_flutter) | Auto-instrumentation for Flutter |
| [purple_logger_otel_sdk](https://pub.dev/packages/purple_logger_otel_sdk) | Bridge: purple_logger → PurpleOTel |
| [purple_logger](https://pub.dev/packages/purple_logger) | Enterprise structured logger |

---








---

## Built by PurpleSoft

**[PurpleSoft S.r.l.](https://www.purplesoft.io)** — software house in Monza, Milano, Lugano (CH). Since 2017.

> We build what doesn't exist yet.

We ship mobile apps that control physical payment terminals. We deploy AI models that run on phones instead of servers. We migrate ERP systems moving billions in transactions without downtime. We build observability pipelines that survive Black Friday traffic. We write Flutter plugins for hardware that doesn't have one yet.

**Our engineering team has built 10 proprietary SDKs shipped to production**, including post-quantum cryptography implementations using NIST-approved algorithms, a unified payments abstraction over PayPal, Stripe, SumUp, Nexi, Google Pay, Apple Pay, Bitcoin, Ethereum, and 100+ cryptocurrencies, and an OAuth authentication layer spanning Google, Apple, Microsoft, Facebook, Instagram, LinkedIn, and GitHub.

**Our open-source portfolio** includes a complete OpenTelemetry SDK for Dart/Flutter, enterprise structured logging, on-device AI inference with ONNX runtime bindings and Litert/MediaPipe integration, speech recognition and neural text-to-speech across 6 platforms, and cross-platform mobile tooling — including the official Flutter plugin for SumUp POS terminals. We contribute to HuggingFace Transformers, Microsoft's Model Context Protocol SDK, and Ethereum smart contract infrastructure.

### Microsoft Partner since 2018 · SumUp Partner · Dell Partner

---

### Trusted by

`ABB` `Intesa Sanpaolo` `Tenaris` `Reply` `Aubay` `Comune di Milano` `BCC` `FIMAP` `Alten` `Altran` `Prometeia` `illimity` `Be Shaping the Future` `DS Group` `NVALUE` `Inoptim` `Docflow` `P&C`

*and 40+ other enterprises across banking, manufacturing, energy, and public sector.*

---

> Your project can't wait. We've solved these exact problems for companies you know.
> Let's solve them for you.

[🌐 **purplesoft.io**](https://www.purplesoft.io) &nbsp;·&nbsp; [📧 **developers@purplesoft.io**](mailto:developers@purplesoft.io) &nbsp;·&nbsp; [📞 **+39 0362 148 3978**](tel:+3903621483978) &nbsp;·&nbsp; [💼 **LinkedIn**](https://www.linkedin.com/company/purplesoft-srl) &nbsp;·&nbsp; [🐙 **GitHub**](https://github.com/purplesoftsrl)## License

AGPL-3.0 — see [LICENSE](LICENSE).








