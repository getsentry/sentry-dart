@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'native_memory_web_mock.dart'
    if (dart.library.io) 'package:sentry_flutter/src/native/native_memory.dart';

void main() {
  final testSrcList = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
  final testSrcData = testSrcList.buffer.asByteData();

  test('empty list', () async {
    final sut = NativeMemory.fromByteData(ByteData(0));
    expect(sut.length, 0);
    expect(sut.pointer.address, greaterThan(0));
    expect(sut.asTypedList(), isEmpty);
    sut.free();
  });

  test('non-empty list', () async {
    final sut = NativeMemory.fromByteData(testSrcData);
    expect(sut.length, 10);
    expect(sut.pointer.address, greaterThan(0));
    expect(sut.asTypedList(), testSrcList);
    sut.free();
  });

  test('json', () async {
    final sut = NativeMemory.fromByteData(testSrcData);
    final json = sut.toJson();
    expect(json['address'], greaterThan(0));
    expect(json['length'], 10);
    expect(json.entries, hasLength(2));

    final sut2 = NativeMemory.fromJson(json);
    expect(sut2.toJson(), json);
    expect(sut2.asTypedList(), testSrcList);

    expect(sut.pointer, sut2.pointer);
    expect(sut.length, sut2.length);
    sut2.free();
  });
}
