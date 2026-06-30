import 'dart:async';

import 'constants.dart';
import 'hub.dart';
import 'integration.dart';
import 'protocol/sentry_attribute.dart';
import 'protocol/sentry_feature_flag.dart';
import 'protocol/sentry_feature_flags.dart';
import 'sentry_options.dart';

const _maxActiveSpanFeatureFlags = 10;

/// Integration which handles adding feature flags to the scope and active span.
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

    _addFeatureFlagToActiveSpan(hub, flag, result);

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

  void _addFeatureFlagToActiveSpan(Hub hub, String flag, bool result) {
    final activeSpan = hub.getActiveSpan();
    if (activeSpan == null || activeSpan.isEnded) {
      return;
    }

    final key = SemanticAttributesConstants.featureFlagEvaluation(flag);
    final attributes = activeSpan.attributes;
    if (!attributes.containsKey(key)) {
      final featureFlagCount = attributes.keys
          .where((key) => key.startsWith(
                SemanticAttributesConstants.featureFlagEvaluationPrefix,
              ))
          .length;
      if (featureFlagCount >= _maxActiveSpanFeatureFlags) {
        return;
      }
    }

    activeSpan.setAttribute(key, SentryAttribute.bool(result));
  }

  @override
  FutureOr<void> close() {
    _hub = null;
  }
}
