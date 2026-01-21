import '../../../sentry.dart';
import '../../utils/internal_logger.dart';
import 'default_metrics.dart';
import 'noop_metrics.dart';

/// Integration that sets up the default Sentry metrics implementation.
class MetricsSetupIntegration extends Integration<SentryOptions> {
  static const integrationName = 'MetricsSetup';

  @override
  void call(Hub hub, SentryOptions options) {
    if (!options.enableMetrics) {
      internalLogger
          .debug('$integrationName: Metrics disabled, skipping setup');
      return;
    }

    if (options.metrics is! NoOpSentryMetrics) {
      internalLogger.debug(
          '$integrationName: Custom metrics already configured, skipping setup');
      return;
    }

    options.metrics = DefaultSentryMetrics(
        captureMetricCallback: hub.captureMetric,
        clockProvider: options.clock,
        defaultScopeProvider: () => hub.scope);

    options.sdk.addIntegration(integrationName);
    internalLogger.debug('$integrationName: Metrics configured successfully');
  }
}
