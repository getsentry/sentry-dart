// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import '../../../sentry_flutter.dart';
import '../../utils/internal_logger.dart';
import 'standalone_app_start_handler.dart';

/// Installs standalone app-start tracing and tears it down on SDK close.
final class StandaloneAppStartIntegration
    extends Integration<SentryFlutterOptions> {
  static const _integrationName = 'StandaloneAppStart';

  final StandaloneAppStartHandler _handler;

  StandaloneAppStartIntegration(this._handler);

  /// Integrations are awaited by the SDK before `runApp`, so anything escaping
  /// here would leave the app unstarted. App-start tracing is never worth that.
  @override
  Future<void> call(Hub hub, SentryFlutterOptions options) async {
    try {
      if (!options.isTracingEnabled()) {
        internalLogger.info(
          'Skipping $_integrationName integration because tracing is disabled.',
        );
        return;
      }

      if (!options.usesStandaloneAppStart) {
        internalLogger.info(
          'Skipping $_integrationName integration because this platform does not support standalone app-start tracing.',
        );
        return;
      }

      options.sdk.addIntegration(_integrationName);
      options.sdk.addFeature(SentryFeatures.standaloneAppStartTracing);
      await _handler.start(options);
    } catch (exception, stackTrace) {
      internalLogger.error(
        'Error while installing $_integrationName integration',
        error: exception,
        stackTrace: stackTrace,
      );
      if (options.automatedTestMode) {
        rethrow;
      }
    }
  }

  @override
  Future<void> close() => _handler.close();
}
