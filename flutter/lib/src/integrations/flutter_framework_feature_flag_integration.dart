import 'dart:async';

import 'package:sentry/sentry.dart';

// The Flutter framework feature flag works like this:
// An enabled (experimental) feature gets added to the `FLUTTER_ENABLED_FEATURE_FLAGS`
// dart define. Being in there means the feature is enabled, the feature is disabled
// if it's not in there.
// As a result, we also don't know the whole list of flags, but only the active ones.
//
// See https://github.com/flutter/flutter/pull/168437
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
  /// For better tree-shake-ability we only add the integration if any feature flag is enabled.
  void addFlutterFrameworkFeatureFlagIntegration() {
    if(const bool.hasEnvironment('FLUTTER_ENABLED_FEATURE_FLAGS')) {
      add(FlutterFrameworkFeatureFlagIntegration());
    }
  }
}