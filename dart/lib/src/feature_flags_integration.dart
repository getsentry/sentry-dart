import 'dart:async';

import 'hub.dart';
import 'integration.dart';
import 'sentry_options.dart';
import 'protocol/sentry_feature_flags.dart';
import 'protocol/sentry_feature_flag.dart';

/// Integration which handles adding feature flags to the scope.
class FeatureFlagsIntegration extends Integration<SentryOptions> {
  Hub? _hub;

  @override
  void call(Hub hub, SentryOptions options) {
    _hub = hub;
    options.sdk.addIntegration('FeatureFlagsIntegration');
  }

  FutureOr<void> addFeatureFlag(String flag, bool result) async {
    final flags =
        _hub?.scope.contexts[SentryFeatureFlags.type] as SentryFeatureFlags? ??
            SentryFeatureFlags(values: []);
    final values = flags.values;

    if (values.length >= 100) {
      values.removeAt(0);
    }

    final index = values.indexWhere((element) => element.flag == flag);
    if (index != -1) {
      values[index] = SentryFeatureFlag(flag: flag, result: result);
    } else {
      values.add(SentryFeatureFlag(flag: flag, result: result));
    }

    flags.values = values;

    await _hub?.scope.setContexts(SentryFeatureFlags.type, flags);
  }

  @override
  FutureOr<void> close() {
    _hub = null;
  }
}
