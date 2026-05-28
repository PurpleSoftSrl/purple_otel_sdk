import 'package:purple_otel_api/purple_otel_api.dart';
import '../metrics/aggregation.dart';
import '../metrics/stream_store.dart';

final class LongCounter implements Counter<int> {
  final StreamStore<SumAggregator> _store;

  LongCounter(int maxCardinality)
      : _store = StreamStore(CardinalityController(maxCombinations: maxCardinality),
            () => SumAggregator(monotonic: true));

  @override
  void add(int value, {Attributes? attributes}) {
    final agg = _store.getOrCreate(attributes ?? const Attributes.empty());
    agg?.record(value);
  }

  StreamStore<SumAggregator> get store => _store;
}

final class DoubleCounter implements Counter<double> {
  final StreamStore<DoubleSumAggregator> _store;

  DoubleCounter(int maxCardinality)
      : _store = StreamStore(CardinalityController(maxCombinations: maxCardinality),
            () => DoubleSumAggregator(monotonic: true));

  @override
  void add(double value, {Attributes? attributes}) {
    final agg = _store.getOrCreate(attributes ?? const Attributes.empty());
    agg?.record(value);
  }

  StreamStore<DoubleSumAggregator> get store => _store;
}

final class LongUpDownCounter implements UpDownCounter<int> {
  final StreamStore<SumAggregator> _store;

  LongUpDownCounter(int maxCardinality)
      : _store = StreamStore(CardinalityController(maxCombinations: maxCardinality),
            () => SumAggregator(monotonic: false));

  @override
  void add(int value, {Attributes? attributes}) {
    final agg = _store.getOrCreate(attributes ?? const Attributes.empty());
    agg?.record(value);
  }

  StreamStore<SumAggregator> get store => _store;
}

final class DoubleUpDownCounter implements UpDownCounter<double> {
  final StreamStore<DoubleSumAggregator> _store;

  DoubleUpDownCounter(int maxCardinality)
      : _store = StreamStore(CardinalityController(maxCombinations: maxCardinality),
            () => DoubleSumAggregator(monotonic: false));

  @override
  void add(double value, {Attributes? attributes}) {
    final agg = _store.getOrCreate(attributes ?? const Attributes.empty());
    agg?.record(value);
  }

  StreamStore<DoubleSumAggregator> get store => _store;
}

final class LongHistogramImpl implements LongHistogram {
  final StreamStore<HistogramAggregator> _store;
  final List<double> _boundaries;

  LongHistogramImpl({
    required List<double> boundaries,
    int maxCardinality = 2000,
  })  : _boundaries = boundaries,
        _store = StreamStore(CardinalityController(maxCombinations: maxCardinality),
            () => HistogramAggregator(boundaries));

  @override
  void record(int value, {Attributes? attributes}) {
    final agg = _store.getOrCreate(attributes ?? const Attributes.empty());
    agg?.record(value);
  }

  StreamStore<HistogramAggregator> get store => _store;
  List<double> get boundaries => _boundaries;
}

final class DoubleHistogramImpl implements DoubleHistogram {
  final StreamStore<DoubleHistogramAggregator> _store;
  final List<double> _boundaries;

  DoubleHistogramImpl({
    required List<double> boundaries,
    int maxCardinality = 2000,
  })  : _boundaries = boundaries,
        _store = StreamStore(CardinalityController(maxCombinations: maxCardinality),
            () => DoubleHistogramAggregator(boundaries));

  @override
  void record(double value, {Attributes? attributes}) {
    final agg = _store.getOrCreate(attributes ?? const Attributes.empty());
    agg?.record(value);
  }

  StreamStore<DoubleHistogramAggregator> get store => _store;
  List<double> get boundaries => _boundaries;
}
