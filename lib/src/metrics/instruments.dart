import 'package:purple_otel_api/purple_otel_api.dart';
import '../metrics/aggregation.dart';
import '../metrics/stream_store.dart';

/// An SDK implementation of [Counter] for integer values.
///
/// Values are always positive (monotonic). Backed by a [StreamStore] with
/// [SumAggregator] per unique attribute set.
final class LongCounter implements Counter<int> {
  final StreamStore<SumAggregator> _store;

  /// Creates a [LongCounter].
  ///
  /// [maxCardinality] limits the number of unique attribute combinations tracked.
  LongCounter(int maxCardinality)
      : _store = StreamStore(
            CardinalityController(maxCombinations: maxCardinality),
            () => SumAggregator(monotonic: true));

  @override
  void add(int value, {Attributes? attributes}) {
    final agg = _store.getOrCreate(attributes ?? const Attributes.empty());
    agg?.record(value);
  }

  /// The underlying [StreamStore] holding per-attribute-set aggregators.
  StreamStore<SumAggregator> get store => _store;
}

/// An SDK implementation of [Counter] for double-precision values.
///
/// Values are always positive (monotonic). Backed by a [StreamStore] with
/// [DoubleSumAggregator] per unique attribute set.
final class DoubleCounter implements Counter<double> {
  final StreamStore<DoubleSumAggregator> _store;

  /// Creates a [DoubleCounter].
  ///
  /// [maxCardinality] limits the number of unique attribute combinations tracked.
  DoubleCounter(int maxCardinality)
      : _store = StreamStore(
            CardinalityController(maxCombinations: maxCardinality),
            () => DoubleSumAggregator(monotonic: true));

  @override
  void add(double value, {Attributes? attributes}) {
    final agg = _store.getOrCreate(attributes ?? const Attributes.empty());
    agg?.record(value);
  }

  /// The underlying [StreamStore] holding per-attribute-set aggregators.
  StreamStore<DoubleSumAggregator> get store => _store;
}

/// An SDK implementation of [UpDownCounter] for integer values.
///
/// Values can increase or decrease (non-monotonic). Backed by a [StreamStore]
/// with [SumAggregator] per unique attribute set.
final class LongUpDownCounter implements UpDownCounter<int> {
  final StreamStore<SumAggregator> _store;

  /// Creates a [LongUpDownCounter].
  ///
  /// [maxCardinality] limits the number of unique attribute combinations tracked.
  LongUpDownCounter(int maxCardinality)
      : _store = StreamStore(
            CardinalityController(maxCombinations: maxCardinality),
            () => SumAggregator(monotonic: false));

  @override
  void add(int value, {Attributes? attributes}) {
    final agg = _store.getOrCreate(attributes ?? const Attributes.empty());
    agg?.record(value);
  }

  /// The underlying [StreamStore] holding per-attribute-set aggregators.
  StreamStore<SumAggregator> get store => _store;
}

/// An SDK implementation of [UpDownCounter] for double-precision values.
///
/// Values can increase or decrease (non-monotonic). Backed by a [StreamStore]
/// with [DoubleSumAggregator] per unique attribute set.
final class DoubleUpDownCounter implements UpDownCounter<double> {
  final StreamStore<DoubleSumAggregator> _store;

  /// Creates a [DoubleUpDownCounter].
  ///
  /// [maxCardinality] limits the number of unique attribute combinations tracked.
  DoubleUpDownCounter(int maxCardinality)
      : _store = StreamStore(
            CardinalityController(maxCombinations: maxCardinality),
            () => DoubleSumAggregator(monotonic: false));

  @override
  void add(double value, {Attributes? attributes}) {
    final agg = _store.getOrCreate(attributes ?? const Attributes.empty());
    agg?.record(value);
  }

  /// The underlying [StreamStore] holding per-attribute-set aggregators.
  StreamStore<DoubleSumAggregator> get store => _store;
}

/// An SDK implementation of [LongHistogram] for integer values.
///
/// Records values into configurable bucket boundaries and tracks count, sum,
/// min, and max per unique attribute set.
final class LongHistogramImpl implements LongHistogram {
  final StreamStore<HistogramAggregator> _store;
  final List<double> _boundaries;

  /// Creates a [LongHistogramImpl].
  ///
  /// [boundaries] are the upper bounds of histogram buckets.
  /// [maxCardinality] limits the number of unique attribute combinations tracked.
  LongHistogramImpl({
    required List<double> boundaries,
    int maxCardinality = 2000,
  })  : _boundaries = boundaries,
        _store = StreamStore(
            CardinalityController(maxCombinations: maxCardinality),
            () => HistogramAggregator(boundaries));

  @override
  void record(int value, {Attributes? attributes}) {
    final agg = _store.getOrCreate(attributes ?? const Attributes.empty());
    agg?.record(value);
  }

  /// The underlying [StreamStore] holding per-attribute-set aggregators.
  StreamStore<HistogramAggregator> get store => _store;

  /// The upper bounds of histogram buckets.
  List<double> get boundaries => _boundaries;
}

/// An SDK implementation of [DoubleHistogram] for double-precision values.
///
/// Records values into configurable bucket boundaries and tracks count, sum,
/// min, and max per unique attribute set.
final class DoubleHistogramImpl implements DoubleHistogram {
  final StreamStore<DoubleHistogramAggregator> _store;
  final List<double> _boundaries;

  /// Creates a [DoubleHistogramImpl].
  ///
  /// [boundaries] are the upper bounds of histogram buckets.
  /// [maxCardinality] limits the number of unique attribute combinations tracked.
  DoubleHistogramImpl({
    required List<double> boundaries,
    int maxCardinality = 2000,
  })  : _boundaries = boundaries,
        _store = StreamStore(
            CardinalityController(maxCombinations: maxCardinality),
            () => DoubleHistogramAggregator(boundaries));

  @override
  void record(double value, {Attributes? attributes}) {
    final agg = _store.getOrCreate(attributes ?? const Attributes.empty());
    agg?.record(value);
  }

  /// The underlying [StreamStore] holding per-attribute-set aggregators.
  StreamStore<DoubleHistogramAggregator> get store => _store;

  /// The upper bounds of histogram buckets.
  List<double> get boundaries => _boundaries;
}
