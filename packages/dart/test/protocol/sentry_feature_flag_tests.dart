import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final featureFlag = SentryFeatureFlag(
    flag: 'feature_flag_1',
    result: true,
    unknown: testUnknown,
  );
  final featureFlagJson = <String, dynamic>{
    ...testUnknown,
    'flag': 'feature_flag_1',
    'result': true,
  };

  group('json', () {
    test('toJson', () {
      final json = featureFlag.toJson();
      expect(
        DeepCollectionEquality().equals(featureFlagJson, json),
        true,
      );
    });

    test('fromJson', () {
      final featureFlag = SentryFeatureFlag.fromJson(featureFlagJson);
      final json = featureFlag.toJson();

      expect(
        DeepCollectionEquality().equals(featureFlagJson, json),
        true,
      );
    });
  });
}
