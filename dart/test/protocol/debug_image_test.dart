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
}
