import 'package:purple_otel_api/purple_otel_api.dart';

import 'sdk_span_context.dart';

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

  InstrumentationScope get scope => _scope;
  Resource get resource => _resource;
  SpanKind get kind => _kind;
  DateTime get startTime => _startTime;
  DateTime? get endTime => _endTime;
  SpanStatus get status => _status;

  @override
  SpanContext get spanContext => _spanContext.toApi();

  @override
  bool get isRecording => !_ended;

  @override
  void setStatus(SpanStatus status) {
    _status = status;
  }

  @override
  void setAttribute(String key, AttributeValue value) {
    if (_attributes != null && _attributes!.length >= _limits.maxAttributes) return;
    _attributes ??= {};
    _attributes![key] = value;
  }

  @override
  void setAttributes(Attributes attributes) {
    _attributes ??= {};
    for (final key in attributes.entries.keys) {
      if (_attributes!.length >= _limits.maxAttributes) break;
      _attributes![key] = attributes.entries[key]!;
    }
  }

  @override
  void addEvent(String name, {DateTime? timestamp, Attributes? attributes}) {
    if (_events != null && _events!.length >= _limits.maxEvents) return;
    _events ??= [];
    _events!.add(SpanEvent(name: name, timestamp: timestamp ?? DateTime.now(), attributes: attributes));
  }

  @override
  void addLink(SpanContext spanContext, {Attributes? attributes}) {
    if (_links != null && _links!.length >= _limits.maxLinks) return;
    _links ??= [];
    _links!.add(SpanLink(spanContext: spanContext, attributes: attributes));
  }

  @override
  void recordException(Object exception, {StackTrace? stackTrace, Attributes? attributes}) {
    final attrs = <String, AttributeValue>{
      'exception.type': AttributeValue.string(exception.runtimeType.toString()),
      'exception.message': AttributeValue.string(exception.toString()),
    };
    if (stackTrace != null) {
      attrs['exception.stacktrace'] = AttributeValue.string(stackTrace.toString());
    }
    if (attributes != null) {
      for (final key in attributes.entries.keys) {
        attrs[key] = attributes.entries[key]!;
      }
    }
    addEvent('exception', timestamp: DateTime.now(), attributes: Attributes.of(attrs));
  }

  @override
  void updateName(String name) {
    _name = name;
  }

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

  String get name => _name;
  Map<String, AttributeValue> get attributes => Map.unmodifiable(_attributes ?? {});
  List<SpanEvent> get events => List.unmodifiable(_events ?? []);
  List<SpanLink> get links => List.unmodifiable(_links ?? []);
}
