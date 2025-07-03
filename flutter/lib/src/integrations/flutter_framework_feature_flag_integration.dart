import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry/sentry.dart';

const _featureFlag = 'FLUTTER_ENABLED_FEATURE_FLAGS';

// The Flutter framework feature flag works like this:
// An enabled (experimental) feature gets added to the `FLUTTER_ENABLED_FEATURE_FLAGS`
// dart define. Being in there means the feature is enabled, the feature is disabled
// if it's not in there.
// As a result, we also don't know the whole list of flags, but only the active ones.
//
// See
// - https://github.com/flutter/flutter/pull/168437
// - https://github.com/flutter/flutter/pull/171545
//
// The Flutter feature flag implementation is not meant to be public and can change in a patch release.
// See this discussion https://github.com/getsentry/sentry-dart/pull/2991/files#r2183105202
class FlutterFrameworkFeatureFlagIntegration
    extends Integration<SentryOptions> {
  final String flags;

  FlutterFrameworkFeatureFlagIntegration({
    @visibleForTesting this.flags = const String.fromEnvironment(_featureFlag),
  });

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {
    final enabledFeatureFlags = flags.split(',');

    for (final featureFlag in enabledFeatureFlags) {
      Sentry.addFeatureFlag('flutter:$featureFlag', true);
    }
    options.sdk.addIntegration('FlutterFrameworkFeatureFlag');
  }
}

extension FlutterFrameworkFeatureFlagIntegrationX
    on List<Integration<SentryOptions>> {
  /// For better tree-shake-ability we only add the integration if any feature flag is enabled.
  void addFlutterFrameworkFeatureFlagIntegration() {
    if (const bool.hasEnvironment(_featureFlag)) {
      add(FlutterFrameworkFeatureFlagIntegration());
    }
  }
}
