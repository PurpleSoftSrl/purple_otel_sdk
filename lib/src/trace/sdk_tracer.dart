import 'dart:async';

import 'package:purple_otel_api/purple_otel_api.dart';

import '../context/zone_context_storage.dart';
import 'sdk_span.dart';
import 'sdk_span_context.dart';

/// The flagship SDK implementation of [Tracer].
///
/// Creates spans with the configured sampler, ID generator, span limits, and
/// context storage. Parent context is resolved from the active [ContextStorage]
/// when not explicitly provided. Sampling decisions are applied before span
/// creation to avoid unnecessary overhead for dropped traces.
final class SDKTracer implements Tracer {
  final InstrumentationScope _scope;
  final Resource _resource;
  final List<SpanProcessor> _processors;
  final Sampler _sampler;
  final IdGenerator _idGenerator;
  final SpanLimits _spanLimits;
  final ContextStorage _contextStorage;

  /// Creates an [SDKTracer].
  ///
  /// [scope] identifies the instrumentation library that owns this tracer.
  /// [resource] is the entity producing telemetry.
  /// [processors] receive span start and end events.
  /// [sampler] determines whether spans are recorded.
  /// [idGenerator] produces [TraceId] and [SpanId] values.
  /// [spanLimits] constrains attribute, event, and link counts.
  /// [contextStorage] provides implicit parent context; defaults to [ZoneContextStorage].
  SDKTracer({
    required InstrumentationScope scope,
    required Resource resource,
    required List<SpanProcessor> processors,
    required Sampler sampler,
    required IdGenerator idGenerator,
    SpanLimits? spanLimits,
    ContextStorage? contextStorage,
  })  : _scope = scope,
        _resource = resource,
        _processors = processors,
        _sampler = sampler,
        _idGenerator = idGenerator,
        _spanLimits = spanLimits ?? const SpanLimits(),
        _contextStorage = contextStorage ?? ZoneContextStorage();

  /// Starts a new span.
  ///
  /// If [parentContext] is null, the active context from [ContextStorage] is used.
  /// When the parent span context is valid, the trace ID and trace flags are
  /// inherited. Otherwise a new trace ID is generated.
  ///
  /// The sampler is consulted before allocating an [SDKSpan]. If the sampling
  /// decision is [SamplingDecision.drop], a [NoopSpan] is returned instead.
  ///
  /// [kind] defaults to [SpanKind.internal].
  /// [attributes] and [links] are applied to the span before it is returned.
  /// [startTime] defaults to the current time.
  @override
  Span startSpan(
    String name, {
    SpanKind? kind,
    Context? parentContext,
    Attributes? attributes,
    List<SpanLink>? links,
    DateTime? startTime,
  }) {
    final effectiveKind = kind ?? SpanKind.internal;

    final parentCtx = parentContext ?? _contextStorage.current;
    final parentSpan = parentCtx.span;
    final parentSpanContext = parentSpan?.spanContext;

    final traceId = parentSpanContext != null && parentSpanContext.isValid
        ? parentSpanContext.traceId
        : _idGenerator.generateTraceId();

    final spanId = _idGenerator.generateSpanId();

    final traceFlags =
        parentSpanContext != null && parentSpanContext.traceFlags.isSampled
            ? TraceFlags.sampled
            : TraceFlags.none;

    final samplingResult = _sampler.shouldSample(
      parentContext: parentCtx,
      traceId: traceId,
      name: name,
      spanKind: effectiveKind,
      attributes: attributes ?? const Attributes.empty(),
      links: links ?? [],
    );

    final isSampled =
        samplingResult.decision == SamplingDecision.recordAndSample;
    final finalFlags = isSampled ? TraceFlags.sampled : traceFlags;

    final spanContext = SDKSpanContext(
      traceId: traceId,
      spanId: spanId,
      traceFlags: finalFlags,
      traceState: parentSpanContext?.traceState ?? const TraceState.empty(),
    );

    if (samplingResult.decision == SamplingDecision.drop) {
      return const NoopSpan();
    }

    final span = SDKSpan(
      spanContext: spanContext,
      scope: _scope,
      resource: _resource,
      kind: effectiveKind,
      name: name,
      processors: _processors,
      limits: _spanLimits,
      startTime: startTime,
    );

    if (attributes != null) span.setAttributes(attributes);
    if (links != null) {
      for (final link in links) {
        span.addLink(link.spanContext, attributes: link.attributes);
      }
    }

    final ctxWithSpan = parentCtx.withValue(spanContextKey, span);
    Zone.current.fork(zoneValues: {_sdkZoneKey: ctxWithSpan}).run(() {
      for (final processor in _processors) {
        if (processor.isStartRequired) {
          processor.onStart(ctxWithSpan, span);
        }
      }
    });

    return span;
  }
}

final _sdkZoneKey = Object();
