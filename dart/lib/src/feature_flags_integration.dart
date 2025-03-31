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
    options.sdk.addIntegration('featureFlagsIntegration');
  }

  FutureOr<void> addFeatureFlag(String name, bool value) async {
    final flags =
        _hub?.scope.contexts[SentryFeatureFlags.type] as SentryFeatureFlags? ??
            SentryFeatureFlags(values: []);
    final values = flags.values;

    if (values.length >= 100) {
      values.removeAt(0);
    }

    final index = values.indexWhere((element) => element.name == name);
    if (index != -1) {
      values[index] = SentryFeatureFlag(name: name, value: value);
    } else {
      values.add(SentryFeatureFlag(name: name, value: value));
    }

    final newFlags = flags.copyWith(values: values);

    await _hub?.scope.setContexts(SentryFeatureFlags.type, newFlags);
  }

  @override
  FutureOr<void> close() {
    _hub = null;
  }
}
