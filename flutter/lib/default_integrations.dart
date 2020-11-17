import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';

// TODO: we might need flags on options to disable those integrations
// not sure if its possible to use removeIntegration for runZonedGuardedIntegration
// because its an internal method

/// integration that capture errors on the current Isolate Error handler
void isolateErrorIntegration(Hub hub, SentryOptions options) {
  final receivePort = RawReceivePort(
    (dynamic error) async {
      options.logger(SentryLevel.debug, 'Capture from IsolateError $error');

      // https://api.dartlang.org/stable/2.7.0/dart-isolate/Isolate/addErrorListener.html
      // error is a list of 2 elements
      if (error is List<dynamic> && error.length == 2) {
        final dynamic throwable = error.first;
        final dynamic stackTrace = error.last;

        const mechanism = Mechanism(type: 'isolateError', handled: false);
        final throwableMechanism = ThrowableMechanism(mechanism, throwable);

        await Sentry.captureException(throwableMechanism,
            stackTrace: stackTrace);
      }
    },
  );

  Isolate.current.addErrorListener(receivePort.sendPort);

  options.sdk.addIntegration('isolateErrorIntegration');
}

/// integration that capture errors on the FlutterError handler
void flutterErrorIntegration(Hub hub, SentryOptions options) {
  final defaultOnError = FlutterError.onError;

  FlutterError.onError = (FlutterErrorDetails errorDetails) async {
    options.logger(
        SentryLevel.debug, 'Capture from onError ${errorDetails.exception}');

    const mechanism = Mechanism(type: 'FlutterError', handled: false);
    final throwableMechanism =
        ThrowableMechanism(mechanism, errorDetails.exception);

    await hub.captureException(
      throwableMechanism,
      stackTrace: errorDetails.stack,
    );

    // call original handler
    if (defaultOnError != null) {
      defaultOnError(errorDetails);
    }
  };

  options.sdk.addIntegration('flutterErrorIntegration');
}

/// integration that capture errors on the runZonedGuarded error handler
Integration runZonedGuardedIntegration(
  Function callback,
) {
  void integration(Hub hub, SentryOptions options) {
    runZonedGuarded(() {
      callback();
    }, (exception, stackTrace) async {
      const mechanism = Mechanism(type: 'runZonedGuarded', handled: false);
      final throwableMechanism = ThrowableMechanism(mechanism, exception);

      await Sentry.captureException(
        throwableMechanism,
        stackTrace: stackTrace,
      );
    });

    options.sdk.addIntegration('runZonedGuardedIntegration');
  }

  return integration;
}

Integration nativeSdkIntegration(SentryOptions options, MethodChannel channel) {
  Future<void> integration(Hub hub, SentryOptions options) async {
    try {
      await channel.invokeMethod<void>('initNativeSdk', <String, dynamic>{
        'dsn': options.dsn,
        'debug': options.debug,
        'environment': options.environment,
        'release': options.release,
        'enableAutoSessionTracking': options.enableAutoSessionTracking,
        'enableNativeCrashHandling': options.enableNativeCrashHandling,
        'attachStacktrace': options.attachStacktrace,
        'autoSessionTrackingIntervalMillis':
            options.autoSessionTrackingIntervalMillis,
        'dist': options.dist,
        'integrations': options.sdk.integrations,
        'packages':
            options.sdk.packages.map((e) => e.toJson()).toList(growable: false),
        'diagnosticLevel': options.diagnosticLevel.name,
        'maxBreadcrumbs': options.maxBreadcrumbs,
        'anrEnabled': options.anrEnabled,
        'anrTimeoutIntervalMillis': options.anrTimeoutIntervalMillis,
        'enableAutoNativeBreadcrumbs': options.enableAutoNativeBreadcrumbs,
        'cacheDirSize': options.cacheDirSize,
      });

      options.sdk.addIntegration('nativeSdkIntegration');
    } catch (error) {
      options.logger(
        SentryLevel.error,
        'nativeSdkIntegration failed to be installed: $error',
      );
    }
  }

  return integration;
}
