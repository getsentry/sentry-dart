// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import '../../../sentry_flutter.dart';
import '../../utils/internal_logger.dart';
import 'standalone_app_start_lifecycle.dart';

/// Wires the SDK integration lifecycle to standalone app-start tracing.
final class StandaloneAppStartIntegration
    extends Integration<SentryFlutterOptions> {
  static const _integrationName = 'StandaloneAppStart';

  final StandaloneAppStartLifecycle _lifecycle;

  StandaloneAppStartIntegration(this._lifecycle);

  @override
  Future<void> call(Hub hub, SentryFlutterOptions options) async {
    if (!options.isTracingEnabled()) {
      internalLogger.info(
        'Skipping $_integrationName integration because tracing is disabled.',
      );
      return;
    }

    if (!options.enableStandaloneAppStartTracing) {
      internalLogger.info(
        'Skipping $_integrationName integration because standalone app-start tracing is disabled.',
      );
      return;
    }

    options.sdk.addIntegration(_integrationName);
    await _lifecycle.start();
  }

  @override
  Future<void> close() => _lifecycle.close();
}
