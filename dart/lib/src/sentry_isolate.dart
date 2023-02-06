import 'dart:async';
import 'dart:isolate';

import 'package:meta/meta.dart';

import '../sentry.dart';

/// Record isolate errors with the Sentry SDK.
extension SentryIsolate on Isolate {

  /// Calls [addErrorListener] with an error listener from the Sentry SDK. Store
  /// the returned [RawReceivePort] if you want to remove the Sentry listener
  /// again.
  ///
  /// Since isolates run concurrently, it's possible for it to exit before the
  /// error listener is established. To avoid this, start the isolate paused,
  /// add the listener and then resume the isolate.
  RawReceivePort addSentryErrorListener() {
    final hub = Sentry.currentHub;
    final options = hub.options;

    final port = _createPort(hub, options);
    addErrorListener(port.sendPort);
    return port;
  }

  /// Pass the [receivePort] returned from [addSentryErrorListener] to remove
  /// the sentry error listener.
  void removeSentryErrorListener(RawReceivePort receivePort) {
    receivePort.close();
    removeErrorListener(receivePort.sendPort);
  }

  // Helper

  RawReceivePort _createPort(Hub hub, SentryOptions options) {
    return RawReceivePort(
      (dynamic error) async {
        await handleIsolateError(hub, options, error);
      },
    );
  }

  /// Parse and raise an event out of the Isolate error.
  @visibleForTesting
  Future<void> handleIsolateError(
    Hub hub,
    SentryOptions options,
    dynamic error,
  ) async {
    options.logger(SentryLevel.debug, 'Capture from IsolateError $error');

    // https://api.dartlang.org/stable/2.7.0/dart-isolate/Isolate/addErrorListener.html
    // error is a list of 2 elements
    if (error is List && error.length == 2) {
      /// The errors are sent back as two-element lists.
      /// The first element is a `String` representation of the error, usually
      /// created by calling `toString` on the error.
      /// The second element is a `String` representation of an accompanying
      /// stack trace, or `null` if no stack trace was provided.
      /// To convert this back to a [StackTrace] object, use [StackTrace.fromString].
      final String throwable = error.first;
      final String? stackTrace = error.last;

      options.logger(
        SentryLevel.error,
        'Uncaught isolate error',
        logger: 'sentry.isolateError',
        exception: throwable,
        stackTrace:
            stackTrace == null ? null : StackTrace.fromString(stackTrace),
      );

      //  Isolate errors don't crash the App.
      final mechanism = Mechanism(type: 'isolateError', handled: true);
      final throwableMechanism = ThrowableMechanism(mechanism, throwable);
      final event = SentryEvent(
        throwable: throwableMechanism,
        level: SentryLevel.fatal,
        timestamp: hub.options.clock(),
      );

      // marks the span status if none to `internal_error` in case there's an
      // unhandled error
      hub.configureScope((scope) => {
            scope.span?.status ??= const SpanStatus.internalError(),
          });

      await hub.captureEvent(event, stackTrace: stackTrace);
    }
  }
}
