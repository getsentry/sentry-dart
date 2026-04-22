import 'package:sentry/sentry.dart';
import 'package:test/test.dart';
import 'package:collection/collection.dart';

void main() {
  group(SentryCulture, () {
    test('copyWith keeps unchanged', () {
      final data = _generate();
      // ignore: deprecated_member_use_from_same_package
      final copy = data.copyWith();

      expect(
        MapEquality().equals(data.toJson(), copy.toJson()),
        true,
      );
    });

    test('copyWith takes new values', () {
      final data = _generate();
      // ignore: deprecated_member_use_from_same_package
      final copy = data.copyWith(
        calendar: 'calendar',
        displayName: 'displayName',
        is24HourFormat: false, // opposite of the value from _generate
        locale: 'locale',
        timezone: 'timezone',
      );

      expect('calendar', copy.calendar);
      expect('displayName', copy.displayName);
      expect(false, copy.is24HourFormat);
      expect('locale', copy.locale);
      expect('timezone', copy.timezone);
    });
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

    group('toAttributes', () {
      test('returns empty map when all fields are null', () {
        expect(SentryCulture().toAttributes(), isEmpty);
      });

      test('maps populated fields to stable semantic attribute keys', () {
        final attributes = _generate().toAttributes();

        expect(attributes[SemanticAttributesConstants.cultureCalendar]?.value,
            'FooCalendar');
        expect(attributes[SemanticAttributesConstants.cultureCalendar]?.type,
            'string');
        expect(
            attributes[SemanticAttributesConstants.cultureDisplayName]?.value,
            'FooLanguage');
        expect(attributes[SemanticAttributesConstants.cultureLocale]?.value,
            'fo-ba');
        expect(
            attributes[SemanticAttributesConstants.cultureIs24HourFormat]
                ?.value,
            true);
        expect(
            attributes[SemanticAttributesConstants.cultureIs24HourFormat]?.type,
            'boolean');
        expect(attributes[SemanticAttributesConstants.cultureTimezone]?.value,
            'best-timezone');
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
