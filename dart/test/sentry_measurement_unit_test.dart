import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group('$SentryMeasurementUnit', () {
    group('DurationUnit', () {
      test('nanosecond', () {
        expect(SentryMeasurementUnit.nanoSecond.toStringValue(), 'nanosecond');
      });

      test('microsecond', () {
        expect(
            SentryMeasurementUnit.microSecond.toStringValue(), 'microsecond');
      });

      test('millisecond', () {
        expect(
            SentryMeasurementUnit.milliSecond.toStringValue(), 'millisecond');
      });

      test('second', () {
        expect(SentryMeasurementUnit.second.toStringValue(), 'second');
      });

      test('minute', () {
        expect(SentryMeasurementUnit.minute.toStringValue(), 'minute');
      });

      test('hour', () {
        expect(SentryMeasurementUnit.hour.toStringValue(), 'hour');
      });

      test('day', () {
        expect(SentryMeasurementUnit.day.toStringValue(), 'day');
      });

      test('week', () {
        expect(SentryMeasurementUnit.week.toStringValue(), 'week');
      });
    });

    group('FractionUnit', () {
      test('ratio', () {
        expect(SentryMeasurementUnit.ratio.toStringValue(), 'ratio');
      });

      test('percent', () {
        expect(SentryMeasurementUnit.percent.toStringValue(), 'percent');
      });
    });

    group('None', () {
      test('none', () {
        expect(SentryMeasurementUnit.none.toStringValue(), 'none');
      });
    });

    group('InformationUnit', () {
      test('bit', () {
        expect(SentryMeasurementUnit.bit.toStringValue(), 'bit');
      });

      test('byte', () {
        expect(SentryMeasurementUnit.byte.toStringValue(), 'byte');
      });

      test('kilobyte', () {
        expect(SentryMeasurementUnit.kiloByte.toStringValue(), 'kilobyte');
      });

      test('kibibyte', () {
        expect(SentryMeasurementUnit.kibiByte.toStringValue(), 'kibibyte');
      });

      test('megabyte', () {
        expect(SentryMeasurementUnit.megaByte.toStringValue(), 'megabyte');
      });

      test('mebibyte', () {
        expect(SentryMeasurementUnit.mebiByte.toStringValue(), 'mebibyte');
      });

      test('gigabyte', () {
        expect(SentryMeasurementUnit.gigaByte.toStringValue(), 'gigabyte');
      });

      test('gibibyte', () {
        expect(SentryMeasurementUnit.gibiByte.toStringValue(), 'gibibyte');
      });
      test('terabyte', () {
        expect(SentryMeasurementUnit.teraByte.toStringValue(), 'terabyte');
      });
      test('tebibyte', () {
        expect(SentryMeasurementUnit.tebiByte.toStringValue(), 'tebibyte');
      });
      test('petabyte', () {
        expect(SentryMeasurementUnit.petaByte.toStringValue(), 'petabyte');
      });
      test('pebibyte', () {
        expect(SentryMeasurementUnit.pebiByte.toStringValue(), 'pebibyte');
      });
      test('exabyte', () {
        expect(SentryMeasurementUnit.exaByte.toStringValue(), 'exabyte');
      });
      test('exbibyte', () {
        expect(SentryMeasurementUnit.exbiByte.toStringValue(), 'exbibyte');
      });
    });
  });
}
