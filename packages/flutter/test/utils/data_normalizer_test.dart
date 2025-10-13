import 'package:flutter_test/flutter_test.dart';
import 'package:collection/collection.dart';
import 'package:sentry_flutter/src/native/utils/data_normalizer.dart';

void main() {
  group('normalize', () {
    test('primitives', () {
      var expected = <String, dynamic>{
        'null': null,
        'int': 1,
        'float': 1.1,
        'bool': true,
        'string': 'Foo',
      };

      var actual = normalizeMap(expected);
      expect(
        DeepCollectionEquality().equals(actual, expected),
        true,
      );

      expect(normalize(null), null);
      expect(normalize(1), 1);
      expect(normalize(1.1), 1.1);
      expect(normalize(true), true);
      expect(normalize('Foo'), 'Foo');
    });

    test('object', () {
      expect(normalize(_CustomObject()), 'CustomObject()');
    });

    test('object in list', () {
      var input = <String, dynamic>{
        'object': [_CustomObject()]
      };
      var expected = <String, dynamic>{
        'object': ['CustomObject()']
      };

      var actual = normalize(input);
      expect(
        DeepCollectionEquality().equals(actual, expected),
        true,
      );
    });

    test('object in map', () {
      var input = <String, dynamic>{
        'object': <String, dynamic>{'object': _CustomObject()}
      };
      var expected = <String, dynamic>{
        'object': <String, dynamic>{'object': 'CustomObject()'}
      };

      var actual = normalize(input);
      expect(
        DeepCollectionEquality().equals(actual, expected),
        true,
      );
    });
  });

  group('normalizeMap', () {
    test('primitives', () {
      var expected = <String, dynamic>{
        'null': null,
        'int': 1,
        'float': 1.1,
        'bool': true,
        'string': 'Foo',
      };

      var actual = normalizeMap(expected);
      expect(
        DeepCollectionEquality().equals(actual, expected),
        true,
      );
    });

    test('list with primitives', () {
      var expected = <String, dynamic>{
        'list': [null, 1, 1.1, true, 'Foo'],
      };

      var actual = normalizeMap(expected);
      expect(
        DeepCollectionEquality().equals(actual, expected),
        true,
      );
    });

    test('map with primitives', () {
      var expected = <String, dynamic>{
        'map': <String, dynamic>{
          'null': null,
          'int': 1,
          'float': 1.1,
          'bool': true,
          'string': 'Foo',
        },
      };

      var actual = normalizeMap(expected);
      expect(
        DeepCollectionEquality().equals(actual, expected),
        true,
      );
    });

    test('object', () {
      var input = <String, dynamic>{'object': _CustomObject()};
      var expected = <String, dynamic>{'object': 'CustomObject()'};

      var actual = normalizeMap(input);
      expect(
        DeepCollectionEquality().equals(actual, expected),
        true,
      );
    });

    test('object in list', () {
      var input = <String, dynamic>{
        'object': [_CustomObject()]
      };
      var expected = <String, dynamic>{
        'object': ['CustomObject()']
      };

      var actual = normalizeMap(input);
      expect(
        DeepCollectionEquality().equals(actual, expected),
        true,
      );
    });

    test('object in map', () {
      var input = <String, dynamic>{
        'object': <String, dynamic>{'object': _CustomObject()}
      };
      var expected = <String, dynamic>{
        'object': <String, dynamic>{'object': 'CustomObject()'}
      };

      var actual = normalizeMap(input);
      expect(
        DeepCollectionEquality().equals(actual, expected),
        true,
      );
    });
  });
}

class _CustomObject {
  @override
  String toString() {
    return 'CustomObject()';
  }
}
