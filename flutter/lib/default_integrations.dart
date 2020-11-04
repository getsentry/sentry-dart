import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:sentry/sentry.dart';

// TODO: we might need flags on options to disable those integrations
// not sure if its possible to use removeIntegration for runZonedGuardedIntegration
// because its an internal method

/// integration that capture errors on the current Isolate Error handler
void isolateErrorIntegration(Hub hub, SentryOptions options) {
  final receivePort = RawReceivePort(
    (dynamic error) async {
      options.logger(SentryLevel.debug, 'Capture from IsolateError $error');

      // TODO: create mechanism

      // https://api.dartlang.org/stable/2.7.0/dart-isolate/Isolate/addErrorListener.html
      // error is a list of 2 elements
      if (error is List<dynamic> && error.length == 2) {
        dynamic stackTrace = error.last;
        if (stackTrace != null) {
          stackTrace = StackTrace.fromString(stackTrace as String);
        }
        await Sentry.captureException(error.first, stackTrace: stackTrace);
      }
    },
  );

  Isolate.current.addErrorListener(receivePort.sendPort);
}

/// integration that capture errors on the FlutterError handler
void flutterErrorIntegration(Hub hub, SentryOptions options) {
  final defaultOnError = FlutterError.onError;

  FlutterError.onError = (FlutterErrorDetails errorDetails) async {
    options.logger(
        SentryLevel.debug, 'Capture from onError ${errorDetails.exception}');

    // TODO: create mechanism

    await hub.captureException(
      errorDetails.exception,
      stackTrace: errorDetails.stack,
    );

    // call original handler
    if (defaultOnError != null) {
      defaultOnError(errorDetails);
    }
  };
}

/// integration that capture errors on the runZonedGuarded error handler
Integration runZonedGuardedIntegration(
  Function callback,
) {
  void integration(Hub hub, SentryOptions options) {
    runZonedGuarded(() {
      callback();
    }, (exception, stackTrace) async {
      // TODO: create mechanism

      await Sentry.captureException(
        exception,
        stackTrace: stackTrace,
      );
    });
  }

  return integration;
}
