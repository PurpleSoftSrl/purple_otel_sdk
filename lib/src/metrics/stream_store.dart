import 'dart:collection';

import 'package:purple_otel_api/purple_otel_api.dart';
import 'aggregation.dart';

final class CardinalityController {
  final int _maxCombinations;
  final LinkedHashMap<int, Attributes> _streams = LinkedHashMap();
  int _overflowCount = 0;

  CardinalityController({int maxCombinations = 2000})
      : _maxCombinations = maxCombinations;

  int get overflowCount => _overflowCount;
  int get activeStreams => _streams.length;

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

  Attributes? getAttributes(int hash) => _streams[hash];

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

  void clear() {
    _streams.clear();
    _overflowCount = 0;
  }
}

final class StreamStore<T> {
  final Map<int, T> _streams = {};
  final CardinalityController _cardinality;
  final T Function() _factory;

  StreamStore(this._cardinality, this._factory);

  int get activeStreams => _streams.length;
  int get overflowCount => _cardinality.overflowCount;

  T? getOrCreate(Attributes attributes) {
    final hash = _cardinality.register(attributes);
    if (hash == null) return null;
    return _streams.putIfAbsent(hash, _factory);
  }

  T? get(Attributes attributes) {
    final hash = CardinalityController._hashAttributes(attributes);
    return _streams[hash];
  }

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

  CardinalityController get cardinality => _cardinality;
}
