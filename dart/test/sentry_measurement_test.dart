import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group('$SentryMeasurement', () {
    test('total frames has none unit', () {
      expect(
          SentryMeasurement.totalFrames(10).unit, SentryMeasurementUnit.none);
    });

    test('slow frames has none unit', () {
      expect(SentryMeasurement.slowFrames(10).unit, SentryMeasurementUnit.none);
    });

    test('frozen frames has none unit', () {
      expect(
          SentryMeasurement.frozenFrames(10).unit, SentryMeasurementUnit.none);
    });

    test('warm start has milliseconds unit', () {
      expect(SentryMeasurement.warmAppStart(Duration(seconds: 1)).unit,
          DurationSentryMeasurementUnit.milliSecond);
    });

    test('cold start has milliseconds unit', () {
      expect(SentryMeasurement.coldAppStart(Duration(seconds: 1)).unit,
          DurationSentryMeasurementUnit.milliSecond);
    });

    test('toJson sets unit if given', () {
      final measurement = SentryMeasurement('name', 10,
          unit: DurationSentryMeasurementUnit.milliSecond);
      final map = <String, dynamic>{
        'value': 10,
        'unit': 'millisecond',
      };

      expect(MapEquality().equals(measurement.toJson(), map), true);
    });
  });
}
