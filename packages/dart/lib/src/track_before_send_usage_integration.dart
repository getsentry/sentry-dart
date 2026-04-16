import 'package:meta/meta.dart';

import 'constants.dart';
import 'hub.dart';
import 'integration.dart';
import 'sentry_options.dart';

/// Registers SDK feature flags for configured `beforeSend*` callbacks.
/// This allows us to track which callbacks are used in the SDK.
@internal
class TrackBeforeSendUsageIntegration extends Integration<SentryOptions> {
  @override
  void call(Hub hub, SentryOptions options) {
    if (options.beforeSend != null) {
      options.sdk.addFeature(SentryFeatures.beforeSendEvent);
    }
    if (options.beforeSendTransaction != null) {
      options.sdk.addFeature(SentryFeatures.beforeSendTransaction);
    }
    if (options.beforeSendFeedback != null) {
      options.sdk.addFeature(SentryFeatures.beforeSendFeedback);
    }
    if (options.beforeSendLog != null) {
      options.sdk.addFeature(SentryFeatures.beforeSendLog);
    }
    if (options.beforeSendMetric != null) {
      options.sdk.addFeature(SentryFeatures.beforeSendMetric);
    }
  }
}
