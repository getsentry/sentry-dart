import '../../../sentry.dart';
import '../../utils/internal_logger.dart';
import '../telemetry_trace_context.dart';
import 'default_logger.dart';
import 'noop_logger.dart';

/// Integration that sets up the default Sentry logger implementation.
class LoggerSetupIntegration extends Integration<SentryOptions> {
  static const integrationName = 'LoggerSetup';

  @override
  void call(Hub hub, SentryOptions options) {
    if (options.logger is! NoOpSentryLogger) {
      internalLogger.debug(
        '$integrationName: Custom logger already configured, skipping setup',
      );
      return;
    }

    options.logger = DefaultSentryLogger(
      captureLogCallback: hub.captureLog,
      clockProvider: options.clock,
      traceContextProvider: () => resolveTelemetryTraceContext(hub),
    );

    options.sdk.addIntegration(integrationName);
    internalLogger.debug('$integrationName: Logger configured successfully');
  }
}
