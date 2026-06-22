import 'package:test/test.dart';
import 'package:sentry/sentry.dart';

void main() {
  group('SentryAttribute', () {
    group('when serializing to JSON', () {
      test('string serializes value with string type', () {
        final attribute = SentryAttribute.string('test');
        expect(attribute.toJson(), {
          'value': 'test',
          'type': 'string',
        });
      });

      test('bool serializes value with boolean type', () {
        final attribute = SentryAttribute.bool(true);
        expect(attribute.toJson(), {
          'value': true,
          'type': 'boolean',
        });
      });

      test('int serializes value with integer type', () {
        final attribute = SentryAttribute.int(1);
        expect(attribute.toJson(), {
          'value': 1,
          'type': 'integer',
        });
      });

      test('double serializes value with double type', () {
        final attribute = SentryAttribute.double(1.0);
        expect(attribute.toJson(), {
          'value': 1.0,
          'type': 'double',
        });
      });

      group('with array values', () {
        test('string array serializes values with array type', () {
          final attribute = SentryAttribute.stringArray(['a', 'b']);
          expect(attribute.toJson(), {
            'value': ['a', 'b'],
            'type': 'array',
          });
        });

        test('int array serializes values with array type', () {
          final attribute = SentryAttribute.intArray([1, 2]);
          expect(attribute.toJson(), {
            'value': [1, 2],
            'type': 'array',
          });
        });

        test('double array serializes values with array type', () {
          final attribute = SentryAttribute.doubleArray([1.0, 2.0]);
          expect(attribute.toJson(), {
            'value': [1.0, 2.0],
            'type': 'array',
          });
        });

        test('bool array serializes values with array type', () {
          final attribute = SentryAttribute.boolArray([true, false]);
          expect(attribute.toJson(), {
            'value': [true, false],
            'type': 'array',
          });
        });

        test('empty array serializes empty list with array type', () {
          final attribute = SentryAttribute.stringArray([]);
          expect(attribute.toJson(), {
            'value': <String>[],
            'type': 'array',
          });
        });
      });
    });
  });
}
