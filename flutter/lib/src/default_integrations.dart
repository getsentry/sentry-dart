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
            sdk.addPackage(package['sdk_name'], package['version']);
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

Integration loadImageList(
  SentryOptions options,
  MethodChannel channel,
) {
  // TODO: ideally this would be already set
  final versions = options.sdk.version.split('.');
  final fullPatch = versions[2];
  // because of -alpha sufix
  final path = fullPatch.split('-');

  final sdkInfo = SdkInfo(
      sdkName: options.sdk.name,
      versionMajor: int.parse(versions[0]),
      versionMinor: int.parse(versions[1]),
      versionPatchlevel: int.parse(path[0]));

  Future<void> integration(Hub hub, SentryOptions options) async {
    options.addEventProcessor(
      (event, dynamic hint) async {
        try {
          final List<Map<dynamic, dynamic>> imageList =
              List<Map<dynamic, dynamic>>.from(
            await channel.invokeMethod('loadImageList'),
          );

          if (imageList.isEmpty) {
            return event;
          }

          final List<DebugImage> newDebugImages = [];

          for (final item in imageList) {
            final image_addr = item['image_addr'] as String;
            final image_size = item['image_size'] as int;
            final code_file = item['code_file'] as String;
            final type = item['type'] as String;
            final debug_id = item['debug_id'] as String;
            final code_id = item['code_id'] as String;
            final debug_file = item['debug_file'] as String;

            final image = DebugImage(
              type: type,
              imageAddr: image_addr,
              imageSize: image_size,
              codeFile: code_file,
              debugId: debug_id,
              codeId: code_id,
              debugFile: debug_file,
            );
            newDebugImages.add(image);
          }

          final debugMeta = DebugMeta(sdk: sdkInfo, images: newDebugImages);

          event = event.copyWith(debugMeta: debugMeta);
        } catch (error) {
          options.logger(
            SentryLevel.error,
            'loadImageList failed : $error',
          );
        }

        return event;
      },
    );

    options.sdk.addIntegration('loadContextsIntegration');
  }

  return integration;
}
