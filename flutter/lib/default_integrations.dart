import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';

/// integration that capture errors on the current Isolate Error handler
/// which is the main thread.
void isolateErrorIntegration(Hub hub, SentryOptions options) {
  final receivePort = _createPort(hub, options);

  Isolate.current.addErrorListener(receivePort.sendPort);

  options.sdk.addIntegration('isolateErrorIntegration');
}

void captureIsolateError(Hub hub, SentryOptions options, dynamic error) {}

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

/// integration that capture errors on the FlutterError handler
void flutterErrorIntegration(Hub hub, SentryOptions options) {
  final defaultOnError = FlutterError.onError;

  FlutterError.onError = (FlutterErrorDetails errorDetails) async {
    options.logger(
        SentryLevel.debug, 'Capture from onError ${errorDetails.exception}');

    // FlutterError doesn't crash the App.
    const mechanism = Mechanism(type: 'FlutterError', handled: true);
    final throwableMechanism =
        ThrowableMechanism(mechanism, errorDetails.exception);

    final event = SentryEvent(
      throwable: throwableMechanism,
      level: SentryLevel.fatal,
    );

    await hub.captureEvent(event, stackTrace: errorDetails.stack);

    // call original handler
    if (defaultOnError != null) {
      defaultOnError(errorDetails);
    }

    // we don't call Zone.current.handleUncaughtError because we'd like
    // to set a specific mechanism for FlutterError.onError.
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
      // runZonedGuarded doesn't crash the App.
      const mechanism = Mechanism(type: 'runZonedGuarded', handled: true);
      final throwableMechanism = ThrowableMechanism(mechanism, exception);

      final event = SentryEvent(
        throwable: throwableMechanism,
        level: SentryLevel.fatal,
      );

      await hub.captureEvent(event, stackTrace: stackTrace);
    });

    options.sdk.addIntegration('runZonedGuardedIntegration');
  }

  return integration;
}

/// (iOS only)
/// add an event processor to call a native channel method to load :
/// - the device Contexts,
/// - and the native sdk integrations and packages
///
Integration loadContextsIntegration(
  SentryOptions options,
  MethodChannel channel,
) {
  Future<void> integration(Hub hub, SentryOptions options) async {
    options.addEventProcessor(
      (event, dynamic hint) async {
        try {
          final Map<String, dynamic> infos = Map<String, dynamic>.from(
            await channel.invokeMethod('loadContexts'),
          );
          if (infos['contexts'] != null) {
            final contexts = Contexts.fromJson(
              Map<String, dynamic>.from(infos['contexts'] as Map),
            );
            final eventContexts = event.contexts.clone();

            contexts.forEach(
              (key, dynamic value) {
                if (value != null) {
                  if (key == SentryRuntime.listType) {
                    contexts.runtimes.forEach(eventContexts.addRuntime);
                  } else if (eventContexts[key] == null) {
                    eventContexts[key] = value;
                  }
                }
              },
            );
            event = event.copyWith(contexts: eventContexts);
          }

          if (infos['integrations'] != null) {
            final integrations =
                List<String>.from(infos['integrations'] as List);
            final sdk = event.sdk ?? options.sdk;
            integrations.forEach(sdk.addIntegration);
            event = event.copyWith(sdk: sdk);
          }

          if (infos['package'] != null) {
            final package = Map<String, String>.from(infos['package'] as Map);
            final sdk = event.sdk ?? options.sdk;
            sdk.addPackage(package['name'], package['version']);
            event = event.copyWith(sdk: sdk);
          }
        } catch (error) {
          options.logger(
            SentryLevel.error,
            'loadContextsIntegration failed : $error',
          );
        }

        return event;
      },
    );

    options.sdk.addIntegration('loadContextsIntegration');
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
        SentryLevel.fatal,
        'nativeSdkIntegration failed to be installed: $error',
      );
    }
  }

  return integration;
}
