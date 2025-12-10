// ignore_for_file: depend_on_referenced_packages

@TestOn('vm')

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jni/jni.dart';
import 'package:sentry_flutter/src/native/java/sentry_native_java.dart';

import 'utils.dart';

final _customObject = CustomObject();

final _nestedMap = {
  'innerString': 'nested',
  'innerList': [1, null, 2],
  'innerNull': null,
};

final _testList = [
  'value',
  1,
  1.1,
  true,
  _customObject,
  ['nestedList', 2],
  _nestedMap,
  null,
];

final _testMap = {
  'key': 'value',
  'key2': 1,
  'key3': 1.1,
  'key4': true,
  'key5': _customObject,
  'list': _testList,
  'nestedMap': _nestedMap,
  'nullEntry': null,
};

const _expectedListLength = 7;
const _expectedNestedListLength = 2;
const _expectedMapLength = 7;

void main() {
  group('JNI (Android)', () {
    test('dartToJObject converts primitives', () {
      _expectJniStringEquals(dartToJObject('value'), 'value');
      _expectJniLongEquals(dartToJObject(1), 1);
      _expectJniDoubleEquals(dartToJObject(1.1), 1.1);
      _expectJniBoolEquals(dartToJObject(true), true);
      _expectJniStringEquals(
          dartToJObject(_customObject), _customObject.toString());
    });

    test('dartToJObject converts list (drops nulls)', () {
      final jList = dartToJObject(_testList).as(JList.type(JObject.type));
      addTearDown(jList.release);
      _verifyJniList(jList);
    });

    test('dartToJObject converts map (drops null values)', () {
      final jMap =
          dartToJObject(_testMap).as(JMap.type(JString.type, JObject.type));
      addTearDown(jMap.release);
      _verifyJniMap(jMap);
    });

    test('dartToJList', () {
      final jList = dartToJList(_testList);
      addTearDown(jList.release);
      _verifyJniList(jList);
    });

    test('dartToJMap', () {
      final jMap = dartToJMap(_testMap);
      addTearDown(jMap.release);
      _verifyJniMap(jMap);
    });
  }, skip: !Platform.isAndroid);
}

void _expectJniStringEquals(JObject? obj, String expected) {
  expect(obj, isNotNull);
  final jString = obj!.as(JString.type);
  expect(jString.toDartString(releaseOriginal: true), expected);
}

void _expectJniLongEquals(JObject? obj, int expected) {
  expect(obj, isNotNull);
  final jLong = obj!.as(JLong.type);
  expect(jLong.longValue(releaseOriginal: true), expected);
}

void _expectJniDoubleEquals(JObject? obj, double expected) {
  expect(obj, isNotNull);
  final jDouble = obj!.as(JDouble.type);
  expect(jDouble.doubleValue(releaseOriginal: true), expected);
}

void _expectJniBoolEquals(JObject? obj, bool expected) {
  expect(obj, isNotNull);
  final jBoolean = obj!.as(JBoolean.type);
  expect(jBoolean.booleanValue(releaseOriginal: true), expected);
}

JObject? _jniGetValue(JMap<JString, JObject> map, String key) {
  final jKey = key.toJString();
  try {
    return map[jKey];
  } finally {
    jKey.release();
  }
}

bool _jniIsNull(JObject? obj) => obj == null || obj.toString() == 'null';

void _verifyJniList(JList<JObject> list) {
  expect(list.length, _expectedListLength);

  _expectJniStringEquals(list[0], 'value');
  _expectJniLongEquals(list[1], 1);
  _expectJniDoubleEquals(list[2], 1.1);
  _expectJniBoolEquals(list[3], true);
  _expectJniStringEquals(list[4], _customObject.toString());

  final nestedList = list[5].as(JList.type(JObject.type));
  expect(nestedList.length, _expectedNestedListLength);
  _expectJniStringEquals(nestedList[0], 'nestedList');
  _expectJniLongEquals(nestedList[1], 2);
  nestedList.release();

  final nestedMap = list[6].as(JMap.type(JString.type, JObject.type));
  _verifyJniNestedMap(nestedMap);
  nestedMap.release();
}

void _verifyJniMap(JMap<JString, JObject> map) {
  expect(map.length, _expectedMapLength);

  _expectJniStringEquals(_jniGetValue(map, 'key'), 'value');
  _expectJniLongEquals(_jniGetValue(map, 'key2'), 1);
  _expectJniDoubleEquals(_jniGetValue(map, 'key3'), 1.1);
  _expectJniBoolEquals(_jniGetValue(map, 'key4'), true);
  _expectJniStringEquals(_jniGetValue(map, 'key5'), _customObject.toString());

  final nestedList = _jniGetValue(map, 'list')!.as(JList.type(JObject.type));
  _verifyJniList(nestedList);
  nestedList.release();

  final nestedMap =
      _jniGetValue(map, 'nestedMap')!.as(JMap.type(JString.type, JObject.type));
  _verifyJniNestedMap(nestedMap);
  nestedMap.release();

  expect(_jniIsNull(_jniGetValue(map, 'nullEntry')), isTrue);
}

void _verifyJniNestedMap(JMap<JString, JObject> map) {
  _expectJniStringEquals(_jniGetValue(map, 'innerString'), 'nested');

  final innerList =
      _jniGetValue(map, 'innerList')!.as(JList.type(JObject.type));
  expect(innerList.length, _expectedNestedListLength);
  _expectJniLongEquals(innerList[0], 1);
  _expectJniLongEquals(innerList[1], 2);
  innerList.release();

  expect(_jniIsNull(_jniGetValue(map, 'innerNull')), isTrue);
}
