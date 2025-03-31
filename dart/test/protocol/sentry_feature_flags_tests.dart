import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final featureFlags = SentryFeatureFlags(
    values: [
      SentryFeatureFlag(name: 'feature_flag_1', value: true),
      SentryFeatureFlag(name: 'feature_flag_2', value: false),
    ],
    unknown: testUnknown,
  );
  final featureFlagsJson = <String, dynamic>{
    ...testUnknown,
    'values': [
      {'name': 'feature_flag_1', 'value': true},
      {'name': 'feature_flag_2', 'value': false},
    ],
  };

  group('json', () {
    test('toJson', () {
      final json = featureFlags.toJson();
      expect(
        DeepCollectionEquality().equals(featureFlagsJson, json),
        true,
      );
    });

    test('fromJson', () {
      final featureFlags = SentryFeatureFlags.fromJson(featureFlagsJson);
      final json = featureFlags.toJson();

      expect(
        DeepCollectionEquality().equals(featureFlagsJson, json),
        true,
      );
    });
  });
}
