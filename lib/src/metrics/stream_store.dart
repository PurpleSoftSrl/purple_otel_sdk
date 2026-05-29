import 'dart:collection';

import 'package:purple_otel_api/purple_otel_api.dart';
import 'aggregation.dart';

/// Controls the number of unique attribute combinations tracked per metric stream.
///
/// When the cardinality limit is exceeded, new attribute combinations are dropped
/// and counted in [overflowCount].
final class CardinalityController {
  final int _maxCombinations;
  final LinkedHashMap<int, Attributes> _streams = LinkedHashMap();
  int _overflowCount = 0;

  /// Creates a [CardinalityController].
  ///
  /// [maxCombinations] is the maximum number of unique attribute sets allowed;
  /// defaults to `2000`.
  CardinalityController({int maxCombinations = 2000})
      : _maxCombinations = maxCombinations;

  /// The number of attribute combinations dropped due to exceeding the limit.
  int get overflowCount => _overflowCount;

  /// The current number of active attribute combinations.
  int get activeStreams => _streams.length;

  /// Registers an attribute set, returning its hash key.
  ///
  /// Returns `null` when the cardinality limit has been reached and the
  /// combination cannot be registered.
  int? register(Attributes attributes) {
    final hash = _hashAttributes(attributes);
    if (_streams.containsKey(hash)) return hash;
    if (_streams.length >= _maxCombinations) {
      _overflowCount++;
      return null;
    }
    _streams[hash] = attributes;
    return hash;
  }

  /// Returns the [Attributes] for a given [hash], or `null` if not found.
  Attributes? getAttributes(int hash) => _streams[hash];

  /// Returns a snapshot of all registered attribute sets keyed by hash.
  Map<int, Attributes> snapshotAttributes() =>
      Map<int, Attributes>.from(_streams);

  static int _hashAttributes(Attributes attrs) {
    var h = 0;
    for (final key in attrs.entries.keys) {
      h = 31 * h + key.hashCode;
      h = 31 * h + (attrs.entries[key]?.hashCode ?? 0);
    }
    return h;
  }

  /// Clears all registered attribute combinations and resets the overflow counter.
  void clear() {
    _streams.clear();
    _overflowCount = 0;
  }
}

/// A generic store that maps attribute hashes to aggregator instances.
///
/// Each unique attribute set gets its own `T` instance via [getOrCreate], subject
/// to the configured [CardinalityController] limit. [collectAndReset] returns
/// a snapshot of all current aggregators, optionally resetting them.
final class StreamStore<T> {
  final Map<int, T> _streams = {};
  final CardinalityController _cardinality;
  final T Function() _factory;

  /// Creates a [StreamStore].
  ///
  /// [cardinality] controls the maximum number of unique attribute combinations.
  /// [factory] creates a new aggregator instance for each unique attribute set.
  StreamStore(this._cardinality, this._factory);

  /// The number of active attribute combinations currently tracked.
  int get activeStreams => _streams.length;

  /// The number of attribute combinations dropped due to cardinality limits.
  int get overflowCount => _cardinality.overflowCount;

  /// Returns or creates an aggregator for the given [attributes].
  ///
  /// Returns `null` when the cardinality limit has been exceeded.
  T? getOrCreate(Attributes attributes) {
    final hash = _cardinality.register(attributes);
    if (hash == null) return null;
    return _streams.putIfAbsent(hash, _factory);
  }

  /// Looks up an existing aggregator for [attributes], or returns `null`.
  T? get(Attributes attributes) {
    final hash = CardinalityController._hashAttributes(attributes);
    return _streams[hash];
  }

  /// Returns a snapshot of all current aggregator instances.
  ///
  /// If [reset] is `true`, the store and cardinality controller are cleared
  /// after the snapshot is taken. For cumulative collectors, aggregators are
  /// copied before being returned to preserve ongoing state.
  Map<int, T> collectAndReset(bool reset) {
    if (reset) {
      final snapshot = Map<int, T>.from(_streams);
      _streams.clear();
      _cardinality.clear();
      return snapshot;
    }
    final result = <int, T>{};
    for (final entry in _streams.entries) {
      if (entry.value is SumAggregator) {
        result[entry.key] = (entry.value as SumAggregator).copy() as T;
      } else if (entry.value is DoubleSumAggregator) {
        result[entry.key] = (entry.value as DoubleSumAggregator).copy() as T;
      } else if (entry.value is HistogramAggregator) {
        result[entry.key] = (entry.value as HistogramAggregator).copy() as T;
      } else if (entry.value is DoubleHistogramAggregator) {
        result[entry.key] =
            (entry.value as DoubleHistogramAggregator).copy() as T;
      } else if (entry.value is LastValueAggregator) {
        result[entry.key] = (entry.value as LastValueAggregator).copy() as T;
      }
    }
    return result;
  }

  /// The [CardinalityController] managing this store's attribute limits.
  CardinalityController get cardinality => _cardinality;
}
