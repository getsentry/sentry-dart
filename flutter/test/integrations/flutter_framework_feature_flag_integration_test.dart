import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/integrations/flutter_framework_feature_flag_integration.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  group(FlutterFrameworkFeatureFlagIntegration, () {
    test('adds sdk integration', () {
      final options = defaultTestOptions();
      FlutterFrameworkFeatureFlagIntegration(flags: 'foo,bar,baz')
          .call(MockHub(), options);

      expect(
          options.sdk.integrations
              .contains('FlutterFrameworkFeatureFlag'),
          true);
    });

    test('adds feature flags', () {
      final options = defaultTestOptions();
      FlutterFrameworkFeatureFlagIntegration(flags: 'foo,bar,baz')
          .call(MockHub(), options);

      // TODO what expect to write here?
    });
  });
}
