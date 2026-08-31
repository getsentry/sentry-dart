// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';
import '../utils/internal_logger.dart';

// TODO(buenaflor): marking this internal until we can find a robust way to unify the TTID/TTFD implementation as currently it is very fragmented.

/// A fallback app–start integration for platforms without built-in app-start timing.
///
/// The Sentry Cocoa and Android SDKs include calls to capture the
/// exact application start timestamp. Other platforms—such as web, desktop,
/// or any SDK that doesn’t (yet) expose app-start instrumentation can use this
/// integration as a reasonable alternative. It measures the duration from
/// integration call to the first completed frame.
@internal
class GenericAppStartIntegration extends Integration<SentryFlutterOptions> {
  GenericAppStartIntegration([FrameCallbackHandler? frameHandler])
    : _framesHandler = frameHandler ?? DefaultFrameCallbackHandler();

  final FrameCallbackHandler _framesHandler;

  static const String integrationName = 'GenericAppStart';

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    if (!options.isTracingEnabled()) return;

    if (options.traceLifecycle == SentryTraceLifecycle.stream) {
      options.timeToDisplayTrackerV2.trackAppStart();
      options.sdk.addIntegration(integrationName);
      return;
    }

    options.timeToDisplayTracker.prepareInitialDisplay(options.clock());

    _framesHandler.addPostFrameCallback((_) async {
      try {
        await options.timeToDisplayTracker.recordInitialDisplay(
          options.clock(),
        );

        // Note: we do not set app start transaction measurements (yet) on purpose
        // This integration is used for TTID/TTFD mainly
        // However this may change in the future.
      } catch (exception, stackTrace) {
        internalLogger.error(
          'An exception occurred while executing the $GenericAppStartIntegration',
          error: exception,
          stackTrace: stackTrace,
        );
        if (options.automatedTestMode) {
          rethrow;
        }
      }
    });

    options.sdk.addIntegration(integrationName);
  }
}
