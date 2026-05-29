import 'dart:typed_data';

final class SumAggregator {
  int _value = 0;
  bool _monotonic;

  SumAggregator({bool monotonic = true}) : _monotonic = monotonic;

  int get value => _value;
  bool get isMonotonic => _monotonic;

  void record(int value) {
    if (_monotonic && value < 0) return;
    _value += value;
  }

  SumAggregator copy() => SumAggregator(monotonic: _monotonic).._value = _value;
  void reset() => _value = 0;
}

final class DoubleSumAggregator {
  double _value = 0.0;
  bool _monotonic;

  DoubleSumAggregator({bool monotonic = true}) : _monotonic = monotonic;

  double get value => _value;
  bool get isMonotonic => _monotonic;

  void record(double value) {
    if (_monotonic && value < 0) return;
    _value += value;
  }

  DoubleSumAggregator copy() =>
      DoubleSumAggregator(monotonic: _monotonic).._value = _value;
  void reset() => _value = 0.0;
}

final class LastValueAggregator<T extends num> {
  T _value;
  bool _hasValue = false;

  LastValueAggregator(T initialValue) : _value = initialValue;

  T get value => _value;
  bool get hasValue => _hasValue;

  void record(T value) {
    _value = value;
    _hasValue = true;
  }

  LastValueAggregator<T> copy() =>
      LastValueAggregator<T>(_value).._hasValue = _hasValue;
  void reset() => _hasValue = false;
}

final class HistogramAggregator {
  final List<double> _boundaries;
  final Int64List _bucketCounts;
  int _sum = 0;
  int _count = 0;
  int _min = 0;
  int _max = 0;
  bool _hasMinMax = false;

  HistogramAggregator(this._boundaries)
      : _bucketCounts = Int64List(_boundaries.length + 1);

  List<double> get boundaries => _boundaries;
  Int64List get bucketCounts => _bucketCounts;
  int get sum => _sum;
  int get count => _count;
  int get min => _min;
  int get max => _max;

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

  void reset() {
    for (var i = 0; i < _bucketCounts.length; i++) {
      _bucketCounts[i] = 0;
    }
    _sum = 0;
    _count = 0;
    _hasMinMax = false;
  }
}

final class DoubleHistogramAggregator {
  final List<double> _boundaries;
  final Int64List _bucketCounts;
  double _sum = 0.0;
  int _count = 0;
  double _min = 0.0;
  double _max = 0.0;
  bool _hasMinMax = false;

  DoubleHistogramAggregator(this._boundaries)
      : _bucketCounts = Int64List(_boundaries.length + 1);

  List<double> get boundaries => _boundaries;
  Int64List get bucketCounts => _bucketCounts;
  double get sum => _sum;
  int get count => _count;
  double get min => _min;
  double get max => _max;

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

  void reset() {
    for (var i = 0; i < _bucketCounts.length; i++) {
      _bucketCounts[i] = 0;
    }
    _sum = 0.0;
    _count = 0;
    _hasMinMax = false;
  }
}
