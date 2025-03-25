import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group(SentryCulture, () {
    test('toJson', () {
      final data = _generate();

      expect(data.toJson(), <String, dynamic>{
        'calendar': 'FooCalendar',
        'display_name': 'FooLanguage',
        'is_24_hour_format': true,
        'locale': 'fo-ba',
        'timezone': 'best-timezone',
      });
    });
  });
}

SentryCulture _generate() => SentryCulture(
      calendar: 'FooCalendar',
      displayName: 'FooLanguage',
      is24HourFormat: true,
      locale: 'fo-ba',
      timezone: 'best-timezone',
    );
