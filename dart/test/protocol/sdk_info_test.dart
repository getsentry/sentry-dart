import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final sdkInfo = SdkInfo(
    sdkName: 'sdkName',
    versionMajor: 1,
    versionMinor: 2,
    versionPatchlevel: 3,
    unknown: testUnknown,
  );

  final sdkInfoJson = <String, dynamic>{
    'sdk_name': 'sdkName',
    'version_major': 1,
    'version_minor': 2,
    'version_patchlevel': 3,
  };
  sdkInfoJson.addAll(testUnknown);

  group('json', () {
    test('toJson', () {
      final json = sdkInfo.toJson();

      expect(
        MapEquality().equals(sdkInfoJson, json),
        true,
      );
    });
    test('fromJson', () {
      final sdkInfo = SdkInfo.fromJson(sdkInfoJson);
      final json = sdkInfo.toJson();

      print(sdkInfo);
      print(json);

      expect(
        MapEquality().equals(sdkInfoJson, json),
        true,
      );
    });
  });

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = sdkInfo;

      final copy = data.copyWith();

      expect(
        MapEquality().equals(data.toJson(), copy.toJson()),
        true,
      );
    });
    test('copyWith takes new values', () {
      final data = sdkInfo;

      final copy = data.copyWith(
        sdkName: 'sdkName1',
        versionMajor: 11,
        versionMinor: 22,
        versionPatchlevel: 33,
      );

      expect('sdkName1', copy.sdkName);
      expect(11, copy.versionMajor);
      expect(22, copy.versionMinor);
      expect(33, copy.versionPatchlevel);
    });
  });
}
