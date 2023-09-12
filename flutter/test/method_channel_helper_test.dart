import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/native/method_channel_helper.dart';
import 'package:collection/collection.dart';

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

      var actual = MethodChannelHelper.normalizeMap(expected);
      expect(
        DeepCollectionEquality().equals(actual, expected),
        true,
      );

      expect(MethodChannelHelper.normalize(null), null);
      expect(MethodChannelHelper.normalize(1), 1);
      expect(MethodChannelHelper.normalize(1.1), 1.1);
      expect(MethodChannelHelper.normalize(true), true);
      expect(MethodChannelHelper.normalize('Foo'), 'Foo');
    });

    test('object', () {
      expect(MethodChannelHelper.normalize(_CustomObject()), 'CustomObject()');
    });

    test('object in list', () {
      var input = <String, dynamic>{
        'object': [_CustomObject()]
      };
      var expected = <String, dynamic>{
        'object': ['CustomObject()']
      };

      var actual = MethodChannelHelper.normalize(input);
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

      var actual = MethodChannelHelper.normalize(input);
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

      var actual = MethodChannelHelper.normalizeMap(expected);
      expect(
        DeepCollectionEquality().equals(actual, expected),
        true,
      );
    });

    test('list with primitives', () {
      var expected = <String, dynamic>{
        'list': [null, 1, 1.1, true, 'Foo'],
      };

      var actual = MethodChannelHelper.normalizeMap(expected);
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

      var actual = MethodChannelHelper.normalizeMap(expected);
      expect(
        DeepCollectionEquality().equals(actual, expected),
        true,
      );
    });

    test('object', () {
      var input = <String, dynamic>{'object': _CustomObject()};
      var expected = <String, dynamic>{'object': 'CustomObject()'};

      var actual = MethodChannelHelper.normalizeMap(input);
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

      var actual = MethodChannelHelper.normalizeMap(input);
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

      var actual = MethodChannelHelper.normalizeMap(input);
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
