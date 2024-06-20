import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group('$SentryMeasurementUnit', () {
    group('DurationUnit', () {
      test('nanosecond', () {
        expect(DurationSentryMeasurementUnit.nanoSecond.toStringValue(),
            'nanosecond');
      });

      test('microsecond', () {
        expect(DurationSentryMeasurementUnit.microSecond.toStringValue(),
            'microsecond');
      });

      test('millisecond', () {
        expect(DurationSentryMeasurementUnit.milliSecond.toStringValue(),
            'millisecond');
      });

      test('second', () {
        expect(DurationSentryMeasurementUnit.second.toStringValue(), 'second');
      });

      test('minute', () {
        expect(DurationSentryMeasurementUnit.minute.toStringValue(), 'minute');
      });

      test('hour', () {
        expect(DurationSentryMeasurementUnit.hour.toStringValue(), 'hour');
      });

      test('day', () {
        expect(DurationSentryMeasurementUnit.day.toStringValue(), 'day');
      });

      test('week', () {
        expect(DurationSentryMeasurementUnit.week.toStringValue(), 'week');
      });
    });

    group('FractionUnit', () {
      test('ratio', () {
        expect(FractionSentryMeasurementUnit.ratio.toStringValue(), 'ratio');
      });

      test('percent', () {
        expect(
            FractionSentryMeasurementUnit.percent.toStringValue(), 'percent');
      });
    });

    group('None', () {
      test('none', () {
        expect(SentryMeasurementUnit.none.toStringValue(), 'none');
      });
    });

    group('InformationUnit', () {
      test('bit', () {
        expect(InformationSentryMeasurementUnit.bit.toStringValue(), 'bit');
      });

      test('byte', () {
        expect(InformationSentryMeasurementUnit.byte.toStringValue(), 'byte');
      });

      test('kilobyte', () {
        expect(InformationSentryMeasurementUnit.kiloByte.toStringValue(),
            'kilobyte');
      });

      test('kibibyte', () {
        expect(InformationSentryMeasurementUnit.kibiByte.toStringValue(),
            'kibibyte');
      });

      test('megabyte', () {
        expect(InformationSentryMeasurementUnit.megaByte.toStringValue(),
            'megabyte');
      });

      test('mebibyte', () {
        expect(InformationSentryMeasurementUnit.mebiByte.toStringValue(),
            'mebibyte');
      });

      test('gigabyte', () {
        expect(InformationSentryMeasurementUnit.gigaByte.toStringValue(),
            'gigabyte');
      });

      test('gibibyte', () {
        expect(InformationSentryMeasurementUnit.gibiByte.toStringValue(),
            'gibibyte');
      });
      test('terabyte', () {
        expect(InformationSentryMeasurementUnit.teraByte.toStringValue(),
            'terabyte');
      });
      test('tebibyte', () {
        expect(InformationSentryMeasurementUnit.tebiByte.toStringValue(),
            'tebibyte');
      });
      test('petabyte', () {
        expect(InformationSentryMeasurementUnit.petaByte.toStringValue(),
            'petabyte');
      });
      test('pebibyte', () {
        expect(InformationSentryMeasurementUnit.pebiByte.toStringValue(),
            'pebibyte');
      });
      test('exabyte', () {
        expect(InformationSentryMeasurementUnit.exaByte.toStringValue(),
            'exabyte');
      });
      test('exbibyte', () {
        expect(InformationSentryMeasurementUnit.exbiByte.toStringValue(),
            'exbibyte');
      });
    });

    group('Custom', () {
      test('custom', () {
        expect(CustomSentryMeasurementUnit('custom').toStringValue(), 'custom');
      });
    });
  });
}
