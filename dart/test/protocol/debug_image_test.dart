import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final debugImage = DebugImage(
    type: 'type',
    imageAddr: 'imageAddr',
    debugId: 'debugId',
    debugFile: 'debugFile',
    imageSize: 1,
    uuid: 'uuid',
    codeFile: 'codeFile',
    arch: 'arch',
    codeId: 'codeId',
    unknown: testUnknown,
  );

  final debugImageJson = <String, dynamic>{
    'uuid': 'uuid',
    'type': 'type',
    'debug_id': 'debugId',
    'debug_file': 'debugFile',
    'code_file': 'codeFile',
    'image_addr': 'imageAddr',
    'image_size': 1,
    'arch': 'arch',
    'code_id': 'codeId',
  };
  debugImageJson.addAll(testUnknown);

  group('json', () {
    test('toJson', () {
      final json = debugImage.toJson();

      expect(
        MapEquality().equals(debugImageJson, json),
        true,
      );
    });
    test('fromJson', () {
      final debugImage = DebugImage.fromJson(debugImageJson);
      final json = debugImage.toJson();

      expect(
        MapEquality().equals(debugImageJson, json),
        true,
      );
    });
  });

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = debugImage;

      final copy = data.copyWith();

      expect(
        MapEquality().equals(data.toJson(), copy.toJson()),
        true,
      );
    });

    test('copyWith takes new values', () {
      final data = debugImage;

      final copy = data.copyWith(
        type: 'type1',
        name: 'name',
        imageAddr: 'imageAddr1',
        imageVmAddr: 'imageVmAddr1',
        debugId: 'debugId1',
        debugFile: 'debugFile1',
        imageSize: 2,
        uuid: 'uuid1',
        codeFile: 'codeFile1',
        arch: 'arch1',
        codeId: 'codeId1',
      );

      expect('type1', copy.type);
      expect('imageAddr1', copy.imageAddr);
      expect('debugId1', copy.debugId);
      expect('debugFile1', copy.debugFile);
      expect(2, copy.imageSize);
      expect('uuid1', copy.uuid);
      expect('codeFile1', copy.codeFile);
      expect('arch1', copy.arch);
      expect('codeId1', copy.codeId);
    });
  });
}
