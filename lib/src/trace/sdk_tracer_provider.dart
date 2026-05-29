import 'dart:math';

import 'package:purple_otel_api/purple_otel_api.dart';

import 'sdk_span_context.dart';
import 'sdk_tracer.dart';

/// The flagship SDK implementation of [TracerProvider].
///
/// Creates and caches [SDKTracer] instances keyed by instrumentation scope.
/// Each tracer shares the configured resource, samplers, ID generator, and
/// span processors, ensuring consistent telemetry across the application.
final class SDKTracerProvider implements TracerProvider {
  final Resource _resource;
  final List<SpanProcessor> _processors;
  final Sampler _sampler;
  final IdGenerator _idGenerator;
  final SpanLimits _spanLimits;
  final Map<String, SDKTracer> _tracers = {};

  /// Creates an [SDKTracerProvider].
  ///
  /// [resource] is the entity producing telemetry (service name, version, etc.).
  /// [processors] handle span start and end events for all tracer instances.
  /// [sampler] controls which spans are recorded; defaults to [AlwaysOnSampler].
  /// [idGenerator] produces [TraceId] and [SpanId] values; defaults to [RandomIdGenerator].
  /// [spanLimits] constrains attribute, event, and link counts; defaults to [SpanLimits].
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

  /// Returns or creates a cached [SDKTracer] for the given instrumentation scope.
  ///
  /// [name] identifies the instrumentation library.
  /// [version] is the optional library version.
  /// [schemaUrl] is the optional schema URL for the telemetry.
  @override
  SDKTracer get(String name, {String? version, String? schemaUrl}) {
    final key = '${name}\x00${version ?? ''}\x00${schemaUrl ?? ''}';
    return _tracers.putIfAbsent(
        key,
        () => SDKTracer(
              scope: InstrumentationScope(
                  name: name, version: version, schemaUrl: schemaUrl),
              resource: _resource,
              processors: _processors,
              sampler: _sampler,
              idGenerator: _idGenerator,
              spanLimits: _spanLimits,
            ));
  }

  /// Forces all registered [SpanProcessor] instances to flush pending spans.
  @override
  Future<void> forceFlush() async {
    await Future.wait(_processors.map((p) => p.forceFlush()));
  }

  /// Shuts down all processors and clears the tracer cache.
  @override
  Future<void> shutdown() async {
    _tracers.clear();
    await Future.wait(_processors.map((p) => p.shutdown()));
  }
}

/// A [Sampler] that always returns [SamplingResult.recordAndSample].
///
/// Every span is recorded and exported. Suitable for development and
/// testing environments where full telemetry is desired.
final class AlwaysOnSampler implements Sampler {
  /// Creates a sampler that records and samples every span.
  const AlwaysOnSampler();

  @override
  SamplingResult shouldSample({
    required Context parentContext,
    required TraceId traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes attributes,
    required List<SpanLink> links,
  }) =>
      SamplingResult.recordAndSample;

  @override
  String get description => 'AlwaysOnSampler';
}

/// A [Sampler] that always returns [SamplingResult.drop].
///
/// No spans are recorded or exported. Useful for silencing telemetry
/// in specific contexts while keeping instrumentation in place.
final class AlwaysOffSampler implements Sampler {
  /// Creates a sampler that drops every span.
  const AlwaysOffSampler();

  @override
  SamplingResult shouldSample({
    required Context parentContext,
    required TraceId traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes attributes,
    required List<SpanLink> links,
  }) =>
      SamplingResult.drop;

  @override
  String get description => 'AlwaysOffSampler';
}

/// A [Sampler] that decides based on the parent span's sampling decision.
///
/// If no parent span exists, delegates to [root]. When a parent exists, the
/// decision is determined by whether the parent is remote or local and whether
/// the parent was sampled. This enables consistent trace-level sampling decisions
/// across service boundaries.
final class ParentBasedSampler implements Sampler {
  final Sampler _root;
  final Sampler _remoteParentSampled;
  final Sampler _remoteParentNotSampled;
  final Sampler _localParentSampled;
  final Sampler _localParentNotSampled;

  /// Creates a [ParentBasedSampler].
  ///
  /// [root] is used when no parent span context exists. Defaults for each
  /// sub-sampler follow the OpenTelemetry specification:
  /// sampled parents forward to [AlwaysOnSampler], unsampled to [AlwaysOffSampler].
  ParentBasedSampler(
    this._root, {
    Sampler? remoteParentSampled,
    Sampler? remoteParentNotSampled,
    Sampler? localParentSampled,
    Sampler? localParentNotSampled,
  })  : _remoteParentSampled = remoteParentSampled ?? const AlwaysOnSampler(),
        _remoteParentNotSampled =
            remoteParentNotSampled ?? const AlwaysOffSampler(),
        _localParentSampled = localParentSampled ?? const AlwaysOnSampler(),
        _localParentNotSampled =
            localParentNotSampled ?? const AlwaysOffSampler();

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
        parentContext: parentContext,
        traceId: traceId,
        name: name,
        spanKind: spanKind,
        attributes: attributes,
        links: links,
      );
    }
    final parentSampled = parentSpan.spanContext.isSampled;
    if (parentSpan.spanContext.isRemote) {
      return parentSampled
          ? _remoteParentSampled.shouldSample(
              parentContext: parentContext,
              traceId: traceId,
              name: name,
              spanKind: spanKind,
              attributes: attributes,
              links: links)
          : _remoteParentNotSampled.shouldSample(
              parentContext: parentContext,
              traceId: traceId,
              name: name,
              spanKind: spanKind,
              attributes: attributes,
              links: links);
    }
    return parentSampled
        ? _localParentSampled.shouldSample(
            parentContext: parentContext,
            traceId: traceId,
            name: name,
            spanKind: spanKind,
            attributes: attributes,
            links: links)
        : _localParentNotSampled.shouldSample(
            parentContext: parentContext,
            traceId: traceId,
            name: name,
            spanKind: spanKind,
            attributes: attributes,
            links: links);
  }

  @override
  String get description => 'ParentBasedSampler(root=$_root)';
}

/// A [Sampler] that samples a configurable ratio of traces.
///
/// The sampling decision is made by comparing a random double against [ratio].
/// A ratio of `1.0` samples all traces; `0.0` samples none.
final class TraceIdRatioBasedSampler implements Sampler {
  final double _ratio;
  final Random _random;

  /// Creates a [TraceIdRatioBasedSampler].
  ///
  /// [ratio] must be in the range `[0.0, 1.0]` representing the desired
  /// sampling probability. [random] can be injected for deterministic tests.
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
