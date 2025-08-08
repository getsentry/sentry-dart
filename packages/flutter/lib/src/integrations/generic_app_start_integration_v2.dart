// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';

/// V2 generic app-start integration that uses the new display timing controller.
@internal
class GenericAppStartIntegrationV2 extends Integration<SentryFlutterOptions> {
  GenericAppStartIntegrationV2([FrameCallbackHandler? frameHandler])
      : _framesHandler = frameHandler ?? DefaultFrameCallbackHandler();

  final FrameCallbackHandler _framesHandler;

  static const String integrationName = 'GenericAppStartV2';

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    if (!options.isTracingEnabled()) return;
    if (!options.experimentalUseDisplayTimingV2) return;

    final start = options.clock();
    final handle = options.displayTiming.startApp(name: 'root /', now: start);

    _framesHandler.addPostFrameCallback((_) {
      try {
        handle.endTtid(options.clock());
      } catch (exception, stackTrace) {
        options.log(
          SentryLevel.error,
          'An exception occurred while executing the $integrationName',
          exception: exception,
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
