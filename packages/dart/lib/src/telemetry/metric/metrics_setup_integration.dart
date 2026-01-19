import '../../../sentry.dart';
import 'metrics.dart';
import 'metrics_impl.dart';

class MetricsSetupIntegration extends Integration<SentryOptions> {
  static const integrationName = 'MetricsSetup';

  @override
  void call(Hub hub, SentryOptions options) {
    if (!options.enableMetrics) return;
    if (options.metrics is! NoOpSentryMetrics) return;

    options.metrics = DefaultSentryMetrics(
        captureMetricCallback: hub.captureMetric,
        clockProvider: options.clock,
        defaultScopeProvider: () => hub.scope);

    options.sdk.addIntegration(integrationName);
  }
}
