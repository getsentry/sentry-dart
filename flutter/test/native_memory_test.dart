@TestOn('vm')
library flutter_test;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/native/native_memory.dart'
    if (dart.library.html) 'native_memory_web_mock.dart';

void main() {
  final testSrcList = Uint8List.fromList([1, 2, 3]);

  test('empty list', () async {
    final sut = NativeMemory.fromUint8List(Uint8List.fromList([]));
    expect(sut.length, 0);
    expect(sut.pointer.address, greaterThan(0));
    expect(sut.asTypedList(), isEmpty);
    sut.free();
  });

  test('non-empty list', () async {
    final sut = NativeMemory.fromUint8List(testSrcList);
    expect(sut.length, 3);
    expect(sut.pointer.address, greaterThan(0));
    expect(sut.asTypedList(), testSrcList);
    sut.free();
  });

  test('json', () async {
    final sut = NativeMemory.fromUint8List(testSrcList);
    final json = sut.toJson();
    expect(json['address'], greaterThan(0));
    expect(json['length'], 3);
    expect(json.entries, hasLength(2));

    final sut2 = NativeMemory.fromJson(json);
    expect(sut2.toJson(), json);
    expect(sut2.asTypedList(), testSrcList);

    expect(sut.pointer, sut2.pointer);
    expect(sut.length, sut2.length);
    sut2.free();
  });
}
