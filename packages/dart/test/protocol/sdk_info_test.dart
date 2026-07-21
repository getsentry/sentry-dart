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
}
