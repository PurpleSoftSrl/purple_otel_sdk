import 'dart:math';

import 'package:purple_otel_api/purple_otel_api.dart';

import 'sdk_span_context.dart';
import 'sdk_tracer.dart';

final class SDKTracerProvider implements TracerProvider {
  final Resource _resource;
  final List<SpanProcessor> _processors;
  final Sampler _sampler;
  final IdGenerator _idGenerator;
  final SpanLimits _spanLimits;
  final Map<String, SDKTracer> _tracers = {};

  SDKTracerProvider({
    required Resource resource,
    required List<SpanProcessor> processors,
    Sampler? sampler,
    IdGenerator? idGenerator,
    SpanLimits? spanLimits,
  })  : _resource = resource,
        _processors = List.unmodifiable(processors),
        _sampler = sampler ?? const AlwaysOnSampler(),
        _idGenerator = idGenerator ?? RandomIdGenerator(),
        _spanLimits = spanLimits ?? const SpanLimits();

  @override
  SDKTracer get(String name, {String? version, String? schemaUrl}) {
    final key = '${name}\x00${version ?? ''}\x00${schemaUrl ?? ''}';
    return _tracers.putIfAbsent(key, () => SDKTracer(
      scope: InstrumentationScope(name: name, version: version, schemaUrl: schemaUrl),
      resource: _resource,
      processors: _processors,
      sampler: _sampler,
      idGenerator: _idGenerator,
      spanLimits: _spanLimits,
    ));
  }

  @override
  Future<void> forceFlush() async {
    await Future.wait(_processors.map((p) => p.forceFlush()));
  }

  @override
  Future<void> shutdown() async {
    _tracers.clear();
    await Future.wait(_processors.map((p) => p.shutdown()));
  }
}

final class AlwaysOnSampler implements Sampler {
  const AlwaysOnSampler();

  @override
  SamplingResult shouldSample({
    required Context parentContext,
    required TraceId traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes attributes,
    required List<SpanLink> links,
  }) => SamplingResult.recordAndSample;

  @override
  String get description => 'AlwaysOnSampler';
}

final class AlwaysOffSampler implements Sampler {
  const AlwaysOffSampler();

  @override
  SamplingResult shouldSample({
    required Context parentContext,
    required TraceId traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes attributes,
    required List<SpanLink> links,
  }) => SamplingResult.drop;

  @override
  String get description => 'AlwaysOffSampler';
}

final class ParentBasedSampler implements Sampler {
  final Sampler _root;
  final Sampler _remoteParentSampled;
  final Sampler _remoteParentNotSampled;
  final Sampler _localParentSampled;
  final Sampler _localParentNotSampled;

  ParentBasedSampler(
    this._root, {
    Sampler? remoteParentSampled,
    Sampler? remoteParentNotSampled,
    Sampler? localParentSampled,
    Sampler? localParentNotSampled,
  })  : _remoteParentSampled = remoteParentSampled ?? const AlwaysOnSampler(),
        _remoteParentNotSampled = remoteParentNotSampled ?? const AlwaysOffSampler(),
        _localParentSampled = localParentSampled ?? const AlwaysOnSampler(),
        _localParentNotSampled = localParentNotSampled ?? const AlwaysOffSampler();

  @override
  SamplingResult shouldSample({
    required Context parentContext,
    required TraceId traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes attributes,
    required List<SpanLink> links,
  }) {
    final parentSpan = parentContext.span;
    if (parentSpan == null || !parentSpan.spanContext.isValid) {
      return _root.shouldSample(
        parentContext: parentContext, traceId: traceId, name: name,
        spanKind: spanKind, attributes: attributes, links: links,
      );
    }
    final parentSampled = parentSpan.spanContext.isSampled;
    if (parentSpan.spanContext.isRemote) {
      return parentSampled
          ? _remoteParentSampled.shouldSample(
              parentContext: parentContext, traceId: traceId, name: name,
              spanKind: spanKind, attributes: attributes, links: links)
          : _remoteParentNotSampled.shouldSample(
              parentContext: parentContext, traceId: traceId, name: name,
              spanKind: spanKind, attributes: attributes, links: links);
    }
    return parentSampled
        ? _localParentSampled.shouldSample(
            parentContext: parentContext, traceId: traceId, name: name,
            spanKind: spanKind, attributes: attributes, links: links)
        : _localParentNotSampled.shouldSample(
            parentContext: parentContext, traceId: traceId, name: name,
            spanKind: spanKind, attributes: attributes, links: links);
  }

  @override
  String get description => 'ParentBasedSampler(root=$_root)';
}

final class TraceIdRatioBasedSampler implements Sampler {
  final double _ratio;
  final Random _random;

  TraceIdRatioBasedSampler(this._ratio, {Random? random})
      : _random = random ?? Random();

  @override
  SamplingResult shouldSample({
    required Context parentContext,
    required TraceId traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes attributes,
    required List<SpanLink> links,
  }) {
    return _random.nextDouble() < _ratio
        ? SamplingResult.recordAndSample
        : SamplingResult.drop;
  }

  @override
  String get description => 'TraceIdRatioBasedSampler(ratio=$_ratio)';
}
