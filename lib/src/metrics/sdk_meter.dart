import 'package:purple_otel_api/purple_otel_api.dart';
import 'instruments.dart';

final class SDKMeter implements Meter {

  SDKMeter();

  @override
  LongCounter createCounter(String name, {String? unit, String? description}) =>
      LongCounter(2000);

  @override
  LongUpDownCounter createUpDownCounter(String name, {String? unit, String? description}) =>
      LongUpDownCounter(2000);

  @override
  DoubleHistogramImpl createDoubleHistogram(String name,
      {String? unit, String? description, List<double>? explicitBucketBoundaries}) {
    return DoubleHistogramImpl(
      boundaries: explicitBucketBoundaries ??
          [0.0, 5.0, 10.0, 25.0, 50.0, 75.0, 100.0, 250.0, 500.0, 750.0, 1000.0, 2500.0, 5000.0, 7500.0, 10000.0],
    );
  }

  @override
  LongHistogramImpl createLongHistogram(String name,
      {String? unit, String? description, List<double>? explicitBucketBoundaries}) {
    return LongHistogramImpl(
      boundaries: explicitBucketBoundaries ??
          [0.0, 5.0, 10.0, 25.0, 50.0, 75.0, 100.0, 250.0, 500.0, 750.0, 1000.0, 2500.0, 5000.0, 7500.0, 10000.0],
    );
  }

  @override
  ObservableDoubleGauge createDoubleObservableGauge(String name,
          {String? unit, String? description,
          required List<Measurement<double>> Function() callback}) =>
      _ObservableDoubleGauge(callback);

  @override
  ObservableLongGauge createLongObservableGauge(String name,
          {String? unit, String? description,
          required List<Measurement<int>> Function() callback}) =>
      _ObservableLongGauge(callback);

  @override
  ObservableLongCounter createLongObservableCounter(String name,
          {String? unit, String? description,
          required List<Measurement<int>> Function() callback}) =>
      _ObservableLongCounter(callback);

  @override
  ObservableDoubleCounter createDoubleObservableCounter(String name,
          {String? unit, String? description,
          required List<Measurement<double>> Function() callback}) =>
      _ObservableDoubleCounter(callback);

  @override
  ObservableLongUpDownCounter createLongObservableUpDownCounter(String name,
          {String? unit, String? description,
          required List<Measurement<int>> Function() callback}) =>
      _ObservableLongUpDownCounter(callback);

  @override
  ObservableDoubleUpDownCounter createDoubleObservableUpDownCounter(String name,
          {String? unit, String? description,
          required List<Measurement<double>> Function() callback}) =>
      _ObservableDoubleUpDownCounter(callback);
}

final class _ObservableDoubleGauge implements ObservableDoubleGauge {
  final List<Measurement<double>> Function() _callback;
  _ObservableDoubleGauge(this._callback);
  @override
  void observe(double value, {Attributes? attributes}) {
    _callback();
  }
}

final class _ObservableLongGauge implements ObservableLongGauge {
  final List<Measurement<int>> Function() _callback;
  _ObservableLongGauge(this._callback);
  @override
  void observe(int value, {Attributes? attributes}) {
    _callback();
  }
}

final class _ObservableLongCounter implements ObservableLongCounter {
  final List<Measurement<int>> Function() _callback;
  _ObservableLongCounter(this._callback);
  @override
  void observe(int value, {Attributes? attributes}) {
    _callback();
  }
}

final class _ObservableDoubleCounter implements ObservableDoubleCounter {
  final List<Measurement<double>> Function() _callback;
  _ObservableDoubleCounter(this._callback);
  @override
  void observe(double value, {Attributes? attributes}) {
    _callback();
  }
}

final class _ObservableLongUpDownCounter implements ObservableLongUpDownCounter {
  final List<Measurement<int>> Function() _callback;
  _ObservableLongUpDownCounter(this._callback);
  @override
  void observe(int value, {Attributes? attributes}) {
    _callback();
  }
}

final class _ObservableDoubleUpDownCounter implements ObservableDoubleUpDownCounter {
  final List<Measurement<double>> Function() _callback;
  _ObservableDoubleUpDownCounter(this._callback);
  @override
  void observe(double value, {Attributes? attributes}) {
    _callback();
  }
}
