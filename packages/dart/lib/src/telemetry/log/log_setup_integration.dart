import '../../../sentry.dart';
import '../../utils/internal_logger.dart';
import 'default_logger.dart';
import 'noop_logger.dart';

class LogSetupIntegration extends Integration<SentryOptions> {
  static const integrationName = 'LogSetup';

  @override
  void call(Hub hub, SentryOptions options) {
    if (!options.enableLogs) {
      internalLogger.debug('$integrationName: Logs disabled, skipping setup');
      return;
    }

    if (options.logger is! NoOpSentryLogger) {
      internalLogger.debug(
          '$integrationName: Custom logger already configured, skipping setup');
      return;
    }

    options.logger = DefaultSentryLogger(
      captureLogCallback: hub.captureLog,
      clockProvider: options.clock,
      scopeProvider: () => hub.scope,
    );

    options.sdk.addIntegration(integrationName);
    internalLogger.debug('$integrationName: Logger configured successfully');
  }
}
