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
    final currentFlags =
        _hub?.scope.contexts[SentryFeatureFlags.type] as SentryFeatureFlags?;
    final values = List<SentryFeatureFlag>.from(currentFlags?.values ?? []);

    final index = values.indexWhere((element) => element.flag == flag);
    if (index != -1) {
      values.removeAt(index);
    }

    values.add(SentryFeatureFlag(flag: flag, result: result));

    while (values.length > 100) {
      values.removeAt(0);
    }

    final unknown = currentFlags?.unknown;
    final updatedFlags = SentryFeatureFlags(
      values: values,
      unknown: unknown == null ? null : Map<String, dynamic>.from(unknown),
    );

    await _hub?.scope.setContexts(
      SentryFeatureFlags.type,
      updatedFlags,
    );
  }

  @override
  FutureOr<void> close() {
    _hub = null;
  }
}
