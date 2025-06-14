import 'dart:async';

import 'package:sentry/sentry.dart';

// See the following PS for the introduction
// https://github.com/flutter/flutter/pull/168437
class FlutterFrameworkFeatureFlagIntegration extends Integration<SentryOptions> {
  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {
    final debugEnabledFeatureFlags = <String>{
      ...const String.fromEnvironment('FLUTTER_ENABLED_FEATURE_FLAGS')
          .split(','),
    };

    for(final featureFlag in debugEnabledFeatureFlags) {
      Sentry.addFeatureFlag(featureFlag, true);
    }
    options.sdk.addIntegration('FlutterFrameworkFeatureFlagIntegration');
  }
}

extension FlutterFrameworkFeatureFlagIntegrationX on List<Integration<SentryOptions>> {
  /// For better tree-shake-ability we only add the integration if a feature flag is enabled.
  void addFlutterFrameworkFeatureFlagIntegration() {
    if(const bool.hasEnvironment('FLUTTER_ENABLED_FEATURE_FLAGS')) {
      add(FlutterFrameworkFeatureFlagIntegration());
    }
  }
}