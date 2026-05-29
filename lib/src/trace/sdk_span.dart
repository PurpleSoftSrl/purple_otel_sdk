import 'package:purple_otel_api/purple_otel_api.dart';

import 'sdk_span_context.dart';

/// The flagship SDK implementation of [Span].
///
/// Collects all span data in memory: attributes, events, links, and status.
/// When [end] is called, the span is marked as ended and forwarded to all
/// configured [SpanProcessor] instances for export. Limits from [SpanLimits]
/// are enforced on attribute count, event count, and link count.
final class SDKSpan implements Span {
  final SDKSpanContext _spanContext;
  final InstrumentationScope _scope;
  final Resource _resource;
  final SpanKind _kind;
  final DateTime _startTime;
  final List<SpanProcessor> _processors;
  final SpanLimits _limits;

  String _name;
  DateTime? _endTime;
  Map<String, AttributeValue>? _attributes;
  List<SpanEvent>? _events;
  List<SpanLink>? _links;
  SpanStatus _status = SpanStatus.unset;
  bool _ended = false;

  /// Creates an [SDKSpan].
  ///
  /// [spanContext] is the immutable span identity (trace ID, span ID, flags).
  /// [scope] identifies the instrumentation library that created this span.
  /// [resource] is the entity producing telemetry.
  /// [kind] indicates the span's role (client, server, internal, etc.).
  /// [name] is the human-readable span name.
  /// [processors] receive the span on [end].
  /// [limits] constrain attribute, event, and link counts.
  /// [startTime] defaults to the current time.
  SDKSpan({
    required SDKSpanContext spanContext,
    required InstrumentationScope scope,
    required Resource resource,
    required SpanKind kind,
    required String name,
    required List<SpanProcessor> processors,
    required SpanLimits limits,
    DateTime? startTime,
  })  : _spanContext = spanContext,
        _scope = scope,
        _resource = resource,
        _kind = kind,
        _name = name,
        _startTime = startTime ?? DateTime.now(),
        _processors = processors,
        _limits = limits;

  /// The instrumentation scope that created this span.
  InstrumentationScope get scope => _scope;

  /// The resource describing the entity that produced this span.
  Resource get resource => _resource;

  /// The role or type of this span (client, server, internal, etc.).
  SpanKind get kind => _kind;

  /// The time at which this span was started.
  DateTime get startTime => _startTime;

  /// The time at which this span was ended, or `null` if still recording.
  DateTime? get endTime => _endTime;

  /// The current [SpanStatus] of this span.
  SpanStatus get status => _status;

  @override
  SpanContext get spanContext => _spanContext.toApi();

  @override
  bool get isRecording => !_ended;

  @override
  void setStatus(SpanStatus status) {
    if (_ended) {
      return;
    }
    _status = status;
  }

  /// Sets a single attribute on this span.
  ///
  /// If the span has reached [SpanLimits.maxAttributes], the attribute
  /// is silently dropped. No-op after [end] is called.
  @override
  void setAttribute(String key, AttributeValue value) {
    if (_ended) return;
    if (_attributes != null && _attributes!.length >= _limits.maxAttributes)
      return;
    _attributes ??= {};
    _attributes![key] = value;
  }

  /// Sets multiple attributes on this span.
  ///
  /// Attributes beyond [SpanLimits.maxAttributes] are silently dropped.
  /// Existing attributes with the same key are overwritten.
  @override
  void setAttributes(Attributes attributes) {
    _attributes ??= {};
    for (final key in attributes.entries.keys) {
      if (_attributes!.length >= _limits.maxAttributes) break;
      _attributes![key] = attributes.entries[key]!;
    }
  }

  /// Adds a timestamped event to this span.
  ///
  /// If the span has reached [SpanLimits.maxEvents], the event is silently
  /// dropped. [timestamp] defaults to the current time.
  @override
  void addEvent(String name, {DateTime? timestamp, Attributes? attributes}) {
    if (_events != null && _events!.length >= _limits.maxEvents) return;
    _events ??= [];
    _events!.add(SpanEvent(
        name: name,
        timestamp: timestamp ?? DateTime.now(),
        attributes: attributes));
  }

  /// Adds a link to another span context.
  ///
  /// If the span has reached [SpanLimits.maxLinks], the link is silently dropped.
  @override
  void addLink(SpanContext spanContext, {Attributes? attributes}) {
    if (_links != null && _links!.length >= _limits.maxLinks) return;
    _links ??= [];
    _links!.add(SpanLink(spanContext: spanContext, attributes: attributes));
  }

  /// Records an exception as a span event.
  ///
  /// The exception type and message are stored as attributes on an event named
  /// `"exception"`. [stackTrace] and additional [attributes] are included when
  /// provided. No-op after [end] is called.
  @override
  void recordException(Object exception,
      {StackTrace? stackTrace, Attributes? attributes}) {
    if (_ended) return;
    final attrs = <String, AttributeValue>{
      'exception.type': AttributeValue.string(_safeStr(exception.runtimeType)),
      'exception.message': AttributeValue.string(_safeStr(exception)),
    };
    if (stackTrace != null) {
      attrs['exception.stacktrace'] =
          AttributeValue.string(stackTrace.toString());
    }
    if (attributes != null) {
      for (final key in attributes.entries.keys) {
        attrs[key] = attributes.entries[key]!;
      }
    }
    addEvent('exception',
        timestamp: DateTime.now(), attributes: Attributes.of(attrs));
  }

  /// Updates the human-readable name of this span.
  ///
  /// No-op after [end] is called.
  @override
  void updateName(String name) {
    if (_ended) return;
    _name = name;
  }

  /// Ends this span and forwards it to all registered [SpanProcessor] instances.
  ///
  /// After calling [end], all mutation methods become no-ops. [endTime] defaults
  /// to the current time.
  @override
  void end([DateTime? endTime]) {
    if (_ended) return;
    _ended = true;
    _endTime = endTime ?? DateTime.now();
    for (final processor in _processors) {
      if (processor.isEndRequired) {
        processor.onEnd(this);
      }
    }
  }

  /// The current span name.
  String get name => _name;

  /// An unmodifiable view of the span's attributes.
  Map<String, AttributeValue> get attributes =>
      Map.unmodifiable(_attributes ?? {});

  /// An unmodifiable view of the span's events.
  List<SpanEvent> get events => List.unmodifiable(_events ?? []);

  /// An unmodifiable view of the span's links.
  List<SpanLink> get links => List.unmodifiable(_links ?? []);

  static String _safeStr(Object obj) {
    try {
      return obj.toString();
    } catch (_) {
      return '<error>';
    }
  }
}
