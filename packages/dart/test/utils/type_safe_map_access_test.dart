import 'package:sentry/src/utils/type_safe_map_access.dart';
import 'package:test/test.dart';

void main() {
  group('TypeSafeMapExtension', () {
    group('getString', () {
      test('returns string value when type matches', () {
        final map = <String, dynamic>{'key': 'value'};
        expect(map.getString('key'), 'value');
      });

      test('returns null when key does not exist', () {
        final map = <String, dynamic>{};
        expect(map.getString('key'), isNull);
      });

      test('returns null when value is null', () {
        final map = <String, dynamic>{'key': null};
        expect(map.getString('key'), isNull);
      });

      test('returns null when value is not a string', () {
        final map = <String, dynamic>{'key': 123};
        expect(map.getString('key'), isNull);
      });

      test('returns null for boolean value', () {
        final map = <String, dynamic>{'key': true};
        expect(map.getString('key'), isNull);
      });
    });

    group('getInt', () {
      test('returns int value when type matches', () {
        final map = <String, dynamic>{'key': 42};
        expect(map.getInt('key'), 42);
      });

      test('converts double to int', () {
        final map = <String, dynamic>{'key': 42.7};
        expect(map.getInt('key'), 42);
      });

      test('returns null when key does not exist', () {
        final map = <String, dynamic>{};
        expect(map.getInt('key'), isNull);
      });

      test('returns null when value is null', () {
        final map = <String, dynamic>{'key': null};
        expect(map.getInt('key'), isNull);
      });

      test('returns null when value is not a number', () {
        final map = <String, dynamic>{'key': 'not a number'};
        expect(map.getInt('key'), isNull);
      });

      test('returns null for boolean value', () {
        final map = <String, dynamic>{'key': false};
        expect(map.getInt('key'), isNull);
      });
    });

    group('getDouble', () {
      test('returns double value when type matches', () {
        final map = <String, dynamic>{'key': 42.5};
        expect(map.getDouble('key'), 42.5);
      });

      test('converts int to double', () {
        final map = <String, dynamic>{'key': 42};
        expect(map.getDouble('key'), 42.0);
      });

      test('returns null when key does not exist', () {
        final map = <String, dynamic>{};
        expect(map.getDouble('key'), isNull);
      });

      test('returns null when value is null', () {
        final map = <String, dynamic>{'key': null};
        expect(map.getDouble('key'), isNull);
      });

      test('returns null when value is not a number', () {
        final map = <String, dynamic>{'key': 'not a number'};
        expect(map.getDouble('key'), isNull);
      });

      test('returns null for boolean value', () {
        final map = <String, dynamic>{'key': true};
        expect(map.getDouble('key'), isNull);
      });
    });

    group('getBool', () {
      test('returns bool value when type matches (true)', () {
        final map = <String, dynamic>{'key': true};
        expect(map.getBool('key'), true);
      });

      test('returns bool value when type matches (false)', () {
        final map = <String, dynamic>{'key': false};
        expect(map.getBool('key'), false);
      });

      test('returns true when value is numeric 1', () {
        final map = <String, dynamic>{'key': 1};
        expect(map.getBool('key'), true);
      });

      test('returns false when value is numeric 0', () {
        final map = <String, dynamic>{'key': 0};
        expect(map.getBool('key'), false);
      });

      test('returns true when value is double 1.0', () {
        final map = <String, dynamic>{'key': 1.0};
        expect(map.getBool('key'), true);
      });

      test('returns false when value is double 0.0', () {
        final map = <String, dynamic>{'key': 0.0};
        expect(map.getBool('key'), false);
      });

      test('returns null for other numeric values', () {
        final map = <String, dynamic>{'key': 2};
        expect(map.getBool('key'), isNull);
      });

      test('returns null when key does not exist', () {
        final map = <String, dynamic>{};
        expect(map.getBool('key'), isNull);
      });

      test('returns null when value is null', () {
        final map = <String, dynamic>{'key': null};
        expect(map.getBool('key'), isNull);
      });

      test('returns null when value is not a boolean', () {
        final map = <String, dynamic>{'key': 'true'};
        expect(map.getBool('key'), isNull);
      });
    });

    group('getDateTime', () {
      test('returns DateTime when value is valid ISO8601 string', () {
        final dateTime = DateTime(2023, 10, 15, 12, 30, 45);
        final map = <String, dynamic>{'key': dateTime.toIso8601String()};
        final result = map.getDateTime('key');
        expect(result, isNotNull);
        expect(result!.year, 2023);
        expect(result.month, 10);
        expect(result.day, 15);
      });

      test('returns null when key does not exist', () {
        final map = <String, dynamic>{};
        expect(map.getDateTime('key'), isNull);
      });

      test('returns null when value is null', () {
        final map = <String, dynamic>{'key': null};
        expect(map.getDateTime('key'), isNull);
      });

      test('returns null when value is not a string', () {
        final map = <String, dynamic>{'key': 12345};
        expect(map.getDateTime('key'), isNull);
      });

      test('returns null when date string is invalid', () {
        final map = <String, dynamic>{'key': 'not a date'};
        expect(map.getDateTime('key'), isNull);
      });

      test('returns null when date string is completely invalid', () {
        final map = <String, dynamic>{'key': 'completely invalid date'};
        expect(map.getDateTime('key'), isNull);
      });
    });
  });
}
