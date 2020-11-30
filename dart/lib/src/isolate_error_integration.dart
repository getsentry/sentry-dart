import 'dart:isolate';

import 'hub.dart';
import 'protocol.dart';
import 'sentry_options.dart';
import 'throwable_mechanism.dart';

Integration initIsolateErrorIntegration(
  void Function(Function) getPortDisposer,
) =>
    (Hub hub, SentryOptions options) {
      final receivePort = _createPort(hub, options);

      Isolate.current.addErrorListener(receivePort.sendPort);

      options.sdk.addIntegration('isolateErrorIntegration');
      getPortDisposer(receivePort.close);
    };

RawReceivePort _createPort(Hub hub, SentryOptions options) {
  return RawReceivePort(
    (dynamic error) async {
      await handleIsolateError(hub, options, error);
    },
  );
}

/// Parse and raise an event out of the Isolate error.
/// Visible for testing.
Future<void> handleIsolateError(
  Hub hub,
  SentryOptions options,
  dynamic error,
) async {
  options.logger(SentryLevel.debug, 'Capture from IsolateError $error');

  // https://api.dartlang.org/stable/2.7.0/dart-isolate/Isolate/addErrorListener.html
  // error is a list of 2 elements
  if (error is List<dynamic> && error.length == 2) {
    final dynamic throwable = error.first;
    final dynamic stackTrace = error.last;

    //  Isolate errors don't crash the App.
    const mechanism = Mechanism(type: 'isolateError', handled: true);
    final throwableMechanism = ThrowableMechanism(mechanism, throwable);
    final event = SentryEvent(
      throwable: throwableMechanism,
      level: SentryLevel.fatal,
    );

    await hub.captureEvent(event, stackTrace: stackTrace);
  }
}
