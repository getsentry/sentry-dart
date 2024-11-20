import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final debugMeta = DebugMeta(
    sdk: SdkInfo(
      sdkName: 'sdkName',
    ),
    images: [DebugImage(type: 'macho', uuid: 'uuid')],
    unknown: testUnknown,
  );

  final debugMetaJson = <String, dynamic>{
    'sdk_info': {'sdk_name': 'sdkName'},
    'images': [
      {'uuid': 'uuid', 'type': 'macho'}
    ]
  };
  debugMetaJson.addAll(testUnknown);

  group('json', () {
    test('toJson', () {
      final json = debugMeta.toJson();

      expect(
        DeepCollectionEquality().equals(debugMetaJson, json),
        true,
      );
    });
    test('fromJson', () {
      final debugMeta = DebugMeta.fromJson(debugMetaJson);
      final json = debugMeta.toJson();

      expect(
        DeepCollectionEquality().equals(debugMetaJson, json),
        true,
      );
    });
  });

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = debugMeta;

      final copy = data.copyWith();

      // MapEquality fails for some reason, it probably check the instances equality too
      expect(data.toJson(), copy.toJson());
    });
    test('copyWith takes new values', () {
      final data = debugMeta;

      final newSdkInfo = SdkInfo(
        sdkName: 'sdkName1',
      );
      final newImageList = [DebugImage(type: 'macho', uuid: 'uuid1')];

      final copy = data.copyWith(
        sdk: newSdkInfo,
        images: newImageList,
      );

      expect(
        ListEquality().equals(newImageList, copy.images),
        true,
      );
      expect(
        MapEquality().equals(newSdkInfo.toJson(), copy.sdk!.toJson()),
        true,
      );
    });
  });
}
