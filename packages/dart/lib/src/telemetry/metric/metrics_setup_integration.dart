import '../../../sentry.dart';
import 'metrics.dart';

class MetricsSetupIntegration extends Integration<SentryOptions> {
  static const integrationName = 'MetricsSetup';

  @override
  void call(Hub hub, SentryOptions options) {
    options.metrics = DefaultSentryMetrics(
        isMetricsEnabled: options.enableMetrics,
        captureMetricCallback: hub.captureMetric,
        clockProvider: options.clock,
        defaultScopeProvider: () => hub.scope);

    options.sdk.addIntegration(integrationName);
  }
}
