## 0.1.8

- Includes 0.1.6 and 0.1.7 below, which were tagged but never published to pub.dev.
- Releases are now published from GitHub Actions on version tags.

## 0.1.7

- `OtelHttpClient.send` emits the stable OpenTelemetry HTTP client semantic conventions (`http.request.method`, `url.full`, `url.scheme`, `server.address`, `server.port` and `http.response.status_code`) alongside the legacy `http.*` keys.
- `SDKSpan.recordException` emits `exception.escaped` (default `false`; can be overridden through `attributes`).

## 0.1.6

- Version bump only, no code changes.

## 0.1.5

- No release notes were recorded for this version.

## 0.1.4

- No release notes were recorded for this version.

## 0.1.0

- Initial release
- Full Trace SDK: Provider, Tracer, Span, 4 samplers, W3C TraceContext
- Full Logs SDK: Provider, Logger, LogRecord, Severity mapping
- Full Metrics SDK: Counter, Histogram, UpDownCounter, Observable instruments
- OTLP HTTP export for all signals (manual protobuf encoder)
- ZoneContextStorage with distributed tracing propagation
- Batch processors with configurable batch size, queue size, flush interval
- Console exporters for development and debugging
- CardinalityController for metric stream limits
- Delta/Cumulative temporality support
