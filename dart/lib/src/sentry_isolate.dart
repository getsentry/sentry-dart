import 'dart:isolate';
import 'package:meta/meta.dart';

import 'throwable_mechanism.dart';
import 'protocol.dart';
import 'hub.dart';
import 'hub_adapter.dart';

/// Conveniently spawn an isolate with an attached sentry error listener.
class SentryIsolate {
  /// Calls [Isolate.spawn] with an error listener from the Sentry SDK.
  ///
  /// Providing your own `onError` will not add the listener from Sentry SDK.
  static Future<Isolate> spawn<T>(
      void Function(T message) entryPoint, T message,
      {bool paused = false,
      bool errorsAreFatal = true,
      SendPort? onExit,
      SendPort? onError,
      String? debugName,
      @internal Hub? hub}) async {
    return Isolate.spawn(
      entryPoint,
      message,
      paused: paused,
      errorsAreFatal: errorsAreFatal,
      onExit: onExit,
      onError: onError ?? createPort(hub ?? HubAdapter()).sendPort,
      debugName: debugName,
    );
  }

  @internal
  static RawReceivePort createPort(Hub hub) {
    return RawReceivePort(
      (dynamic error) async {
        await handleIsolateError(hub, error);
      },
    );
  }

  @visibleForTesting

  /// Parse and raise an event out of the Isolate error.
  static Future<void> handleIsolateError(
    Hub hub,
    dynamic error,
  ) async {
    hub.options.logger(SentryLevel.debug, 'Capture from IsolateError $error');

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

      hub.options.logger(
        SentryLevel.error,
        'Uncaught isolate error',
        logger: 'sentry.isolateError',
        exception: throwable,
        stackTrace:
            stackTrace == null ? null : StackTrace.fromString(stackTrace),
      );

      //  Isolate errors don't crash the app, but is not handled by the user.
      final mechanism = Mechanism(type: 'isolateError', handled: false);
      final throwableMechanism = ThrowableMechanism(mechanism, throwable);

      final event = SentryEvent(
        throwable: throwableMechanism,
        level: hub.options.markAutomaticallyCollectedErrorsAsFatal
            ? SentryLevel.fatal
            : SentryLevel.error,
        timestamp: hub.options.clock(),
      );

      // marks the span status if none to `internal_error` in case there's an
      // unhandled error
      hub.configureScope(
        (scope) => scope.span?.status ??= const SpanStatus.internalError(),
      );

      await hub.captureEvent(event, stackTrace: stackTrace);
    }
  }
}
