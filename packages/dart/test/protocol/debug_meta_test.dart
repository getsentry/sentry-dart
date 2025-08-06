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
}
