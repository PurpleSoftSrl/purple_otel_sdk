import 'dart:typed_data';

/// Aggregates integer values into a running sum.
///
/// When [monotonic] is `true` (the default), negative values are silently
/// rejected — suitable for [Counter] instruments. Set to `false` for
/// [UpDownCounter] support.
final class SumAggregator {
  int _value = 0;
  bool _monotonic;

  /// Creates a [SumAggregator].
  ///
  /// [monotonic] defaults to `true`, rejecting negative input values.
  SumAggregator({bool monotonic = true}) : _monotonic = monotonic;

  /// The current accumulated sum.
  int get value => _value;

  /// Whether this aggregator rejects negative input values.
  bool get isMonotonic => _monotonic;

  /// Records [value], adding it to the running sum.
  ///
  /// If [isMonotonic] is `true` and [value] is negative, this call is a no-op.
  void record(int value) {
    if (_monotonic && value < 0) return;
    _value += value;
  }

  /// Returns a copy of this aggregator with the same accumulated state.
  SumAggregator copy() => SumAggregator(monotonic: _monotonic).._value = _value;

  /// Resets the accumulated sum to zero.
  void reset() => _value = 0;
}

/// Aggregates double-precision values into a running sum.
///
/// When [monotonic] is `true` (the default), negative values are silently
/// rejected — suitable for [DoubleCounter] instruments. Set to `false` for
/// [DoubleUpDownCounter] support.
final class DoubleSumAggregator {
  double _value = 0.0;
  bool _monotonic;

  /// Creates a [DoubleSumAggregator].
  ///
  /// [monotonic] defaults to `true`, rejecting negative input values.
  DoubleSumAggregator({bool monotonic = true}) : _monotonic = monotonic;

  /// The current accumulated sum.
  double get value => _value;

  /// Whether this aggregator rejects negative input values.
  bool get isMonotonic => _monotonic;

  /// Records [value], adding it to the running sum.
  ///
  /// If [isMonotonic] is `true` and [value] is negative, this call is a no-op.
  void record(double value) {
    if (_monotonic && value < 0) return;
    _value += value;
  }

  /// Returns a copy of this aggregator with the same accumulated state.
  DoubleSumAggregator copy() =>
      DoubleSumAggregator(monotonic: _monotonic).._value = _value;

  /// Resets the accumulated sum to zero.
  void reset() => _value = 0.0;
}

/// Aggregator that keeps only the last recorded value.
///
/// Suitable for gauge instruments where only the most recent measurement matters.
final class LastValueAggregator<T extends num> {
  T _value;
  bool _hasValue = false;

  /// Creates a [LastValueAggregator] with an [initialValue].
  LastValueAggregator(T initialValue) : _value = initialValue;

  /// The most recently recorded value.
  T get value => _value;

  /// Whether at least one value has been recorded.
  bool get hasValue => _hasValue;

  /// Records [value], replacing any previously stored value.
  void record(T value) {
    _value = value;
    _hasValue = true;
  }

  /// Returns a copy of this aggregator with the same stored value.
  LastValueAggregator<T> copy() =>
      LastValueAggregator<T>(_value).._hasValue = _hasValue;

  /// Marks the aggregator as having no recorded value.
  void reset() => _hasValue = false;
}

/// Aggregates integer values into a histogram distribution.
///
/// Values are assigned to buckets defined by [_boundaries]. Each boundary
/// represents the inclusive upper bound of a bucket. Tracks count, sum, min,
/// and max across all recorded values.
final class HistogramAggregator {
  final List<double> _boundaries;
  final Int64List _bucketCounts;
  int _sum = 0;
  int _count = 0;
  int _min = 0;
  int _max = 0;
  bool _hasMinMax = false;

  /// Creates a [HistogramAggregator] with the given [boundaries].
  ///
  /// An extra bucket for values above the last boundary is automatically added.
  HistogramAggregator(this._boundaries)
      : _bucketCounts = Int64List(_boundaries.length + 1);

  /// The upper bounds of histogram buckets.
  List<double> get boundaries => _boundaries;

  /// The count of observations in each bucket (including the overflow bucket).
  Int64List get bucketCounts => _bucketCounts;

  /// The sum of all observed values.
  int get sum => _sum;

  /// The total number of observations.
  int get count => _count;

  /// The minimum observed value.
  int get min => _min;

  /// The maximum observed value.
  int get max => _max;

  /// Records [value], updating the appropriate bucket and summary statistics.
  void record(int value) {
    _sum += value;
    _count++;
    if (!_hasMinMax) {
      _min = value;
      _max = value;
      _hasMinMax = true;
    } else {
      if (value < _min) _min = value;
      if (value > _max) _max = value;
    }
    final bucket = _findBucket(value);
    _bucketCounts[bucket]++;
  }

  int _findBucket(int value) {
    for (var i = 0; i < _boundaries.length; i++) {
      if (value <= _boundaries[i]) return i;
    }
    return _boundaries.length;
  }

  /// Returns a copy of this aggregator with the same accumulated state.
  HistogramAggregator copy() {
    final h = HistogramAggregator(_boundaries);
    h._bucketCounts.setAll(0, _bucketCounts);
    h._sum = _sum;
    h._count = _count;
    h._min = _min;
    h._max = _max;
    h._hasMinMax = _hasMinMax;
    return h;
  }

  /// Resets all buckets and summary statistics to zero.
  void reset() {
    for (var i = 0; i < _bucketCounts.length; i++) {
      _bucketCounts[i] = 0;
    }
    _sum = 0;
    _count = 0;
    _hasMinMax = false;
  }
}

/// Aggregates double-precision values into a histogram distribution.
///
/// Values are assigned to buckets defined by [_boundaries]. Each boundary
/// represents the inclusive upper bound of a bucket. Tracks count, sum, min,
/// and max across all recorded values. NaN and infinite values are silently
/// rejected.
final class DoubleHistogramAggregator {
  final List<double> _boundaries;
  final Int64List _bucketCounts;
  double _sum = 0.0;
  int _count = 0;
  double _min = 0.0;
  double _max = 0.0;
  bool _hasMinMax = false;

  /// Creates a [DoubleHistogramAggregator] with the given [boundaries].
  ///
  /// An extra bucket for values above the last boundary is automatically added.
  DoubleHistogramAggregator(this._boundaries)
      : _bucketCounts = Int64List(_boundaries.length + 1);

  /// The upper bounds of histogram buckets.
  List<double> get boundaries => _boundaries;

  /// The count of observations in each bucket (including the overflow bucket).
  Int64List get bucketCounts => _bucketCounts;

  /// The sum of all observed values.
  double get sum => _sum;

  /// The total number of observations.
  int get count => _count;

  /// The minimum observed value.
  double get min => _min;

  /// The maximum observed value.
  double get max => _max;

  /// Records [value], updating the appropriate bucket and summary statistics.
  ///
  /// NaN and infinite values are silently dropped.
  void record(double value) {
    if (value.isNaN || value.isInfinite) return;
    _sum += value;
    _count++;
    if (!_hasMinMax) {
      _min = value;
      _max = value;
      _hasMinMax = true;
    } else {
      if (value < _min) _min = value;
      if (value > _max) _max = value;
    }
    final bucket = _findBucket(value);
    _bucketCounts[bucket]++;
  }

  int _findBucket(double value) {
    for (var i = 0; i < _boundaries.length; i++) {
      if (value <= _boundaries[i]) return i;
    }
    return _boundaries.length;
  }

  /// Returns a copy of this aggregator with the same accumulated state.
  DoubleHistogramAggregator copy() {
    final h = DoubleHistogramAggregator(_boundaries);
    h._bucketCounts.setAll(0, _bucketCounts);
    h._sum = _sum;
    h._count = _count;
    h._min = _min;
    h._max = _max;
    h._hasMinMax = _hasMinMax;
    return h;
  }

  /// Resets all buckets and summary statistics to zero.
  void reset() {
    for (var i = 0; i < _bucketCounts.length; i++) {
      _bucketCounts[i] = 0;
    }
    _sum = 0.0;
    _count = 0;
    _hasMinMax = false;
  }
}
