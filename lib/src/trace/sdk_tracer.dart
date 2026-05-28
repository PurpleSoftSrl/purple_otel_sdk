import 'dart:async';

import 'package:purple_otel_api/purple_otel_api.dart';

import '../context/zone_context_storage.dart';
import 'sdk_span.dart';
import 'sdk_span_context.dart';

final class SDKTracer implements Tracer {
  final InstrumentationScope _scope;
  final Resource _resource;
  final List<SpanProcessor> _processors;
  final Sampler _sampler;
  final IdGenerator _idGenerator;
  final SpanLimits _spanLimits;
  final ContextStorage _contextStorage;

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

    final traceFlags = parentSpanContext != null && parentSpanContext.traceFlags.isSampled
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

    final isSampled = samplingResult.decision == SamplingDecision.recordAndSample;
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
