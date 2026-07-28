import 'dart:async';

import 'constants.dart';
import 'hub.dart';
import 'integration.dart';
import 'protocol/sentry_attribute.dart';
import 'protocol/sentry_feature_flag.dart';
import 'protocol/sentry_feature_flags.dart';
import 'protocol/sentry_span.dart';
import 'sentry_options.dart';
import 'sentry_span_interface.dart';
import 'sentry_tracer.dart';
import 'telemetry/span/sentry_span_v2.dart';

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
    if (activeSpan != null) {
      _addFeatureFlagToActiveSpanV2(activeSpan, flag, result);
      return;
    }

    final activeLegacySpan = hub.getSpan();
    if (activeLegacySpan != null) {
      _addFeatureFlagToActiveLegacySpan(activeLegacySpan, flag, result);
    }
  }

  void _addFeatureFlagToActiveSpanV2(
    RecordingSentrySpanV2 span,
    String flag,
    bool result,
  ) {
    if (span.isEnded) {
      return;
    }

    final key = SemanticAttributesConstants.featureFlagEvaluation(flag);
    final attributes = span.attributes;
    if (_hasReachedFeatureFlagLimit(attributes, key)) {
      return;
    }

    span.setAttribute(key, SentryAttribute.bool(result));
  }

  void _addFeatureFlagToActiveLegacySpan(
    ISentrySpan span,
    String flag,
    bool result,
  ) {
    if (span.finished) {
      return;
    }

    final key = SemanticAttributesConstants.featureFlagEvaluation(flag);
    final data = _legacySpanData(span);
    if (data != null && _hasReachedFeatureFlagLimit(data, key)) {
      return;
    }

    span.setData(key, result);
  }

  bool _hasReachedFeatureFlagLimit(Map<String, dynamic> values, String key) {
    if (values.containsKey(key)) {
      return false;
    }

    final featureFlagCount = values.keys
        .where(
          (key) => key.startsWith(
            SemanticAttributesConstants.featureFlagEvaluationPrefix,
          ),
        )
        .length;
    return featureFlagCount >= _maxActiveSpanFeatureFlags;
  }

  Map<String, dynamic>? _legacySpanData(ISentrySpan span) {
    if (span is SentryTracer) {
      return span.data;
    }
    if (span is SentrySpan) {
      return span.data;
    }
    return null;
  }

  @override
  FutureOr<void> close() {
    _hub = null;
  }
}
