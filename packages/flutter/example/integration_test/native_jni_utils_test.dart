// ignore_for_file: depend_on_referenced_packages
@TestOn('vm')

import 'dart:io';

import 'package:test/test.dart';
import 'package:jni/jni.dart';
import 'package:sentry_flutter/src/native/java/sentry_native_java.dart';

import 'utils.dart';

void main() {
  final customObject = CustomObject();

  final inputNestedMap = {
    'innerString': 'nested',
    'innerList': [1, null, 2],
    'innerNull': null,
  };

  final inputList = [
    'value',
    1,
    1.1,
    true,
    customObject,
    ['nestedList', 2],
    inputNestedMap,
    null,
  ];

  final inputMap = {
    'key': 'value',
    'key2': 1,
    'key3': 1.1,
    'key4': true,
    'key5': customObject,
    'list': inputList,
    'nestedMap': inputNestedMap,
    'nullEntry': null,
  };

  final expectedNestedList = ['nestedList', 2];

  final expectedNestedMap = {
    'innerString': 'nested',
    'innerList': [1, 2],
    'innerNull': null,
  };
  final expectedList = [
    'value',
    1,
    1.1,
    true,
    customObject.toString(),
    expectedNestedList,
    expectedNestedMap,
  ];

  final expectedMap = {
    'key': 'value',
    'key2': 1,
    'key3': 1.1,
    'key4': true,
    'key5': customObject.toString(),
    'list': expectedList,
    'nestedMap': expectedNestedMap,
  };

  group('JNI (Android)', () {
    test('dartToJObject converts primitives', () {
      using((arena) {
        _expectJniStringEquals(
            dartToJObject('value')..releasedBy(arena), 'value');
        _expectJniLongEquals(dartToJObject(1)..releasedBy(arena), 1);
        _expectJniDoubleEquals(dartToJObject(1.1)..releasedBy(arena), 1.1);
        _expectJniBoolEquals(dartToJObject(true)..releasedBy(arena), true);
        _expectJniStringEquals(
          dartToJObject(customObject)..releasedBy(arena),
          customObject.toString(),
        );
      });
    });

    test('dartToJObject converts list (drops nulls)', () {
      using((arena) {
        final javaList = dartToJObject(inputList).as(JList.type)
            as JList<JObject>
          ..releasedBy(arena);
        _expectJniList(javaList, expectedList, arena);
      });
    });

    test('dartToJObject converts map (drops null values)', () {
      using((arena) {
        final javaMap = dartToJObject(inputMap).as(JMap.type)
            as JMap<JString, JObject>
          ..releasedBy(arena);
        _expectJniMap(javaMap, expectedMap, arena);
      });
    });

    test('dartToJList', () {
      using((arena) {
        final javaList = dartToJList(inputList)..releasedBy(arena);
        _expectJniList(javaList, expectedList, arena);
      });
    });

    test('dartToJMap', () {
      using((arena) {
        final javaMap = dartToJMap(inputMap)..releasedBy(arena);
        _expectJniMap(javaMap, expectedMap, arena);
      });
    });
  }, skip: !Platform.isAndroid);
}

void _expectJniStringEquals(JObject? javaObject, String expected) {
  expect(javaObject, isNotNull);
  final javaString = javaObject!.as(JString.type);
  expect(javaString.toDartString(releaseOriginal: true), expected);
}

void _expectJniLongEquals(JObject? javaObject, int expected) {
  expect(javaObject, isNotNull);
  final javaLong = javaObject!.as(JLong.type);
  expect(javaLong.toDartInt(releaseOriginal: true), expected);
}

void _expectJniDoubleEquals(JObject? javaObject, double expected) {
  expect(javaObject, isNotNull);
  final javaDouble = javaObject!.as(JDouble.type);
  expect(javaDouble.toDartDouble(releaseOriginal: true), expected);
}

void _expectJniBoolEquals(JObject? javaObject, bool expected) {
  expect(javaObject, isNotNull);
  final javaBoolean = javaObject!.as(JBoolean.type);
  expect(javaBoolean.toDartBool(releaseOriginal: true), expected);
}

JObject? _get(JMap<JString, JObject> javaMap, String key, Arena arena) =>
    javaMap.get(key.toJString()..releasedBy(arena));

void _expectJniList(
  JList<JObject> javaList,
  List<Object?> expectedListValues,
  Arena arena,
) {
  expect(javaList.size(), expectedListValues.length);

  _expectJniStringEquals(javaList.get(0), expectedListValues[0] as String);
  _expectJniLongEquals(javaList.get(1), expectedListValues[1] as int);
  _expectJniDoubleEquals(javaList.get(2), expectedListValues[2] as double);
  _expectJniBoolEquals(javaList.get(3), expectedListValues[3] as bool);
  _expectJniStringEquals(javaList.get(4), expectedListValues[4] as String);

  final nestedList = javaList.get(5)!.as(JList.type) as JList<JObject>
    ..releasedBy(arena);
  final expectedNestedList = expectedListValues[5] as List<Object?>;
  expect(nestedList.size(), expectedNestedList.length);
  _expectJniStringEquals(nestedList.get(0), expectedNestedList[0] as String);
  _expectJniLongEquals(nestedList.get(1), expectedNestedList[1] as int);

  final nestedMap = javaList.get(6)!.as(JMap.type) as JMap<JString, JObject>
    ..releasedBy(arena);
  _expectJniNestedMap(
    nestedMap,
    expectedListValues[6] as Map<String, Object?>,
    expectedNestedList.length,
    arena,
  );
}

void _expectJniMap(
  JMap<JString, JObject> javaMap,
  Map<String, Object?> expectedMapValues,
  Arena arena,
) {
  expect(javaMap.size(), expectedMapValues.length);

  final expectedList = expectedMapValues['list']! as List<Object?>;
  final expectedNestedList = expectedList[5] as List<Object?>;
  final expectedNestedMap =
      expectedMapValues['nestedMap']! as Map<String, Object?>;

  _expectJniStringEquals(
      _get(javaMap, 'key', arena), expectedMapValues['key'] as String);
  _expectJniLongEquals(
      _get(javaMap, 'key2', arena), expectedMapValues['key2'] as int);
  _expectJniDoubleEquals(
      _get(javaMap, 'key3', arena), expectedMapValues['key3'] as double);
  _expectJniBoolEquals(
      _get(javaMap, 'key4', arena), expectedMapValues['key4'] as bool);
  _expectJniStringEquals(
      _get(javaMap, 'key5', arena), expectedMapValues['key5'] as String);

  final nestedList = _get(javaMap, 'list', arena)!.as(JList.type)
      as JList<JObject>
    ..releasedBy(arena);
  _expectJniList(nestedList, expectedList, arena);

  final nestedMap = _get(javaMap, 'nestedMap', arena)!.as(JMap.type)
      as JMap<JString, JObject>
    ..releasedBy(arena);
  _expectJniNestedMap(
      nestedMap, expectedNestedMap, expectedNestedList.length, arena);

  expect(_get(javaMap, 'nullEntry', arena), isNull);
}

void _expectJniNestedMap(
  JMap<JString, JObject> javaNestedMap,
  Map<String, Object?> expectedNestedMapValues,
  int expectedNestedListLength,
  Arena arena,
) {
  _expectJniStringEquals(_get(javaNestedMap, 'innerString', arena),
      expectedNestedMapValues['innerString'] as String);

  final innerList = _get(javaNestedMap, 'innerList', arena)!.as(JList.type)
      as JList<JObject>
    ..releasedBy(arena);
  expect(innerList.size(), expectedNestedListLength);
  _expectJniLongEquals(innerList.get(0),
      (expectedNestedMapValues['innerList']! as List<Object?>)[0] as int);
  _expectJniLongEquals(innerList.get(1),
      (expectedNestedMapValues['innerList']! as List<Object?>)[1] as int);

  expect(_get(javaNestedMap, 'innerNull', arena), isNull);
}
