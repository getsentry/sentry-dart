import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final featureFlag = SentryFeatureFlag(
    name: 'feature_flag_1',
    value: 'value_1',
    unknown: testUnknown,
  );
  final featureFlagJson = <String, dynamic>{
    ...testUnknown,
    'name': 'feature_flag_1',
    'value': 'value_1',
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
