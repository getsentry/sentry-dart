// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../utils/internal_logger.dart';
import 'standalone_app_start_lifecycle.dart';

/// Wires the SDK integration lifecycle to standalone app-start tracing.
final class StandaloneAppStartIntegration
    extends Integration<SentryFlutterOptions> {
  StandaloneAppStartIntegration(this._lifecycle);

  @internal
  static const integrationName = 'StandaloneAppStart';

  final StandaloneAppStartLifecycle _lifecycle;

  @override
  Future<void> call(Hub hub, SentryFlutterOptions options) async {
    if (!options.isTracingEnabled()) {
      internalLogger.info(
        'Skipping $integrationName integration because tracing is disabled.',
      );
      return;
    }

    if (!options.enableStandaloneAppStartTracing) return;

    options.sdk.addIntegration(integrationName);
    await _lifecycle.start(hub, options);
  }

  @override
  Future<void> close() => _lifecycle.close();
}
