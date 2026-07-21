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
