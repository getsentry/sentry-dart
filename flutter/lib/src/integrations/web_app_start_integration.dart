// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';

// buenaflor: marking this internal until we can find a robust way to unify
// the TTID/TTFD implementation as currently it is very fragmented.
@internal
class WebAppStartIntegration extends Integration<SentryFlutterOptions> {
  WebAppStartIntegration([FrameCallbackHandler? frameHandler])
      : _framesHandler = frameHandler ?? DefaultFrameCallbackHandler();

  final FrameCallbackHandler _framesHandler;

  static const String integrationName = 'WebAppStart';

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    if (!options.isTracingEnabled()) return;

    try {
      final transactionContext = SentryTransactionContext(
        'root /',
        SentrySpanOperations.uiLoad,
        origin: SentryTraceOrigins.autoUiTimeToDisplay,
      );
      final startTimeStamp = options.clock();
      // expose id so SentryFlutter.currentDisplay() can return something
      options.timeToDisplayTracker.transactionId = transactionContext.spanId;
      final transaction = hub.startTransactionWithContext(
        transactionContext,
        startTimestamp: startTimeStamp,
      );

      _framesHandler.addPostFrameCallback((_) async {
        final endTimestamp = options.clock();
        await options.timeToDisplayTracker.track(
          transaction,
          ttidEndTimestamp: endTimestamp,
        );

        await transaction.finish(endTimestamp: endTimestamp);
      });

      options.sdk.addIntegration(integrationName);
    } catch (exception, stackTrace) {
      options.log(
        SentryLevel.error,
        'An exception occurred while executing the $WebAppStartIntegration',
        exception: exception,
        stackTrace: stackTrace,
      );
      if (options.automatedTestMode) {
        rethrow;
      }
    }
}
