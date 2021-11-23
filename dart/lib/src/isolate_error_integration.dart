import 'dart:async';
import 'dart:isolate';

import 'package:meta/meta.dart';

import 'hub.dart';
import 'integration.dart';
import 'protocol.dart';
import 'sentry_options.dart';
import 'throwable_mechanism.dart';

class IsolateErrorIntegration extends Integration {
  RawReceivePort? _receivePort;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) async {
    final safeReceivePort = _receivePort = _createPort(hub, options);
    Isolate.current.addErrorListener(safeReceivePort.sendPort);
    options.sdk.addIntegration('isolateErrorIntegration');
  }

  @override
  void close() {
    if (_receivePort != null) {
      final safeReceivePort = _receivePort!;
      safeReceivePort.close();
      Isolate.current.removeErrorListener(safeReceivePort.sendPort);
    }
  }
}

RawReceivePort _createPort(Hub hub, SentryOptions options) {
  return RawReceivePort(
    (Object? error) async {
      await handleIsolateError(hub, options, error);
    },
  );
}

/// Parse and raise an event out of the Isolate error.
@visibleForTesting
Future<void> handleIsolateError(
  Hub hub,
  SentryOptions options,
  Object? error,
) async {
  options.logger(SentryLevel.debug, 'Capture from IsolateError $error');

  // https://api.dartlang.org/stable/2.7.0/dart-isolate/Isolate/addErrorListener.html
  // error is a list of 2 elements
  if (error is List && error.length == 2) {
    final Object? throwable = error.first;
    final String? stackTrace = error.last;

    options.logger(
      SentryLevel.error,
      'Uncaught isolate error',
      logger: 'sentry.isolateError',
      exception: throwable,
      stackTrace: stackTrace == null ? null : StackTrace.fromString(stackTrace),
    );

    //  Isolate errors don't crash the App.
    final mechanism = Mechanism(type: 'isolateError', handled: true);
    final throwableMechanism = ThrowableMechanism(mechanism, throwable);
    final event = SentryEvent(
      throwable: throwableMechanism,
      level: SentryLevel.fatal,
    );

    await hub.captureEvent(event, stackTrace: stackTrace);
  }
}
