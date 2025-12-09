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
      _expectJniString(dartToJObject('value'), 'value');
      _expectJniInt(dartToJObject(1), 1);
      _expectJniDouble(dartToJObject(1.1), 1.1);
      _expectJniBool(dartToJObject(true), true);
      _expectJniString(dartToJObject(_customObject), _customObject.toString());
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

void _expectJniString(JObject obj, String expected) {
  expect(obj, isA<JString>());
  expect((obj as JString).toDartString(releaseOriginal: true), expected);
}

void _expectJniInt(JObject obj, int expected) {
  expect(obj, isA<JLong>());
  expect((obj as JLong).longValue(releaseOriginal: true), expected);
}

void _expectJniDouble(JObject obj, double expected) {
  expect(obj, isA<JDouble>());
  expect((obj as JDouble).doubleValue(releaseOriginal: true), expected);
}

void _expectJniBool(JObject obj, bool expected) {
  expect(obj, isA<JBoolean>());
  expect((obj as JBoolean).booleanValue(releaseOriginal: true), expected);
}

JObject? _jniGet(JMap<JString, JObject> map, String key) {
  final jKey = key.toJString();
  final value = map[jKey];
  jKey.release();
  return value;
}

bool _jniIsNull(JObject? obj) => obj == null || obj.toString() == 'null';

void _verifyJniList(JList<JObject> list) {
  expect(list.length, _expectedListLength);

  // Verify primitives
  expect(list[0].as(JString.type).toDartString(), 'value');
  expect(list[1].as(JLong.type).longValue(), 1);
  expect(list[2].as(JDouble.type).doubleValue(), 1.1);
  expect(list[3].as(JBoolean.type).booleanValue(), isTrue);
  expect(list[4].as(JString.type).toDartString(), _customObject.toString());

  // Verify nested list
  final nestedList = list[5].as(JList.type(JObject.type));
  expect(nestedList.length, 2);
  expect(nestedList[0].as(JString.type).toDartString(), 'nestedList');
  expect(nestedList[1].as(JLong.type).longValue(), 2);
  nestedList.release();

  // Verify nested map
  final nestedMap = list[6].as(JMap.type(JString.type, JObject.type));
  _verifyJniNestedMap(nestedMap);
  nestedMap.release();
}

void _verifyJniMap(JMap<JString, JObject> map) {
  expect(map.length, _expectedMapLength);

  // Verify primitives
  expect(_jniGet(map, 'key')!.as(JString.type).toDartString(), 'value');
  expect(_jniGet(map, 'key2')!.as(JLong.type).longValue(), 1);
  expect(_jniGet(map, 'key3')!.as(JDouble.type).doubleValue(), 1.1);
  expect(_jniGet(map, 'key4')!.as(JBoolean.type).booleanValue(), isTrue);
  expect(_jniGet(map, 'key5')!.as(JString.type).toDartString(),
      _customObject.toString());

  // Verify nested list
  final nestedList = _jniGet(map, 'list')!.as(JList.type(JObject.type));
  _verifyJniList(nestedList);
  nestedList.release();

  // Verify nested map
  final nestedMap =
      _jniGet(map, 'nestedMap')!.as(JMap.type(JString.type, JObject.type));
  _verifyJniNestedMap(nestedMap);
  nestedMap.release();

  // Verify null was dropped
  expect(_jniIsNull(_jniGet(map, 'nullEntry')), isTrue);
}

void _verifyJniNestedMap(JMap<JString, JObject> map) {
  expect(
      _jniGet(map, 'innerString')!.as(JString.type).toDartString(), 'nested');

  final innerList = _jniGet(map, 'innerList')!.as(JList.type(JObject.type));
  expect(innerList.length, _expectedNestedListLength);
  expect(innerList[0].as(JLong.type).longValue(), 1);
  expect(innerList[1].as(JLong.type).longValue(), 2);
  innerList.release();

  // Verify null was dropped
  expect(_jniIsNull(_jniGet(map, 'innerNull')), isTrue);
}
