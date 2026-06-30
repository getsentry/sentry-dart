import 'dart:async';

import 'hub.dart';
import 'integration.dart';
import 'protocol/sentry_feature_flag.dart';
import 'protocol/sentry_feature_flags.dart';
import 'sentry_options.dart';

/// Integration which handles adding feature flags to the scope.
class FeatureFlagsIntegration extends Integration<SentryOptions> {
  Hub? _hub;

  @override
  void call(Hub hub, SentryOptions options) {
    _hub = hub;
    options.sdk.addIntegration('FeatureFlagsIntegration');
  }

  FutureOr<void> addFeatureFlag(String flag, bool result) async {
    final hub = _hub;
    if (hub == null) {
      return;
    }

    final activeSpan = hub.getActiveSpan();
    activeSpan?.addFeatureFlag(flag, result);

    final flags =
        hub.scope.contexts[SentryFeatureFlags.type] as SentryFeatureFlags? ??
            SentryFeatureFlags(values: []);
    final values = List<SentryFeatureFlag>.from(flags.values);

    final index = values.indexWhere((element) => element.flag == flag);
    if (index != -1) {
      values.removeAt(index);
    }

    values.add(SentryFeatureFlag(flag: flag, result: result));

    while (values.length > 100) {
      values.removeAt(0);
    }

    flags.values = values;

    await hub.scope.setContexts(SentryFeatureFlags.type, flags);
  }

  @override
  FutureOr<void> close() {
    _hub = null;
  }
}
