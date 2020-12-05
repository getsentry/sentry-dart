import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:package_info/package_info.dart';
import 'package:sentry/sentry.dart';
import 'sentry_flutter_options.dart';
import 'widgets_binding_observer.dart';

/// integration that capture errors on the FlutterError handler
class FlutterErrorIntegration extends Integration<SentryFlutterOptions> {
  @override
  void call(Hub hub, SentryFlutterOptions options) {
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
}

/// (iOS only)
/// add an event processor to call a native channel method to load :
/// - the device Contexts,
/// - and the native sdk integrations and packages
class LoadContextsIntegration extends Integration<SentryFlutterOptions> {
  final MethodChannel _channel;

  LoadContextsIntegration(this._channel);

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) async {
    options.addEventProcessor(
      (event, {hint}) async {
        try {
          final infos = Map<String, dynamic>.from(
            await _channel.invokeMethod('loadContexts'),
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
}

/// Enables Sentry's native SDKs (Android and iOS)
class NativeSdkIntegration extends Integration<SentryFlutterOptions> {
  final MethodChannel _channel;

  NativeSdkIntegration(this._channel);

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) async {
    try {
      await _channel.invokeMethod<void>('initNativeSdk', <String, dynamic>{
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
}

/// Integration that captures certain window and device events.
/// See also:
///   - [SentryWidgetsBindingObserver]
///   - [WidgetsBindingObserver](https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html)
class WidgetsBindingIntegration extends Integration<SentryFlutterOptions> {
  SentryWidgetsBindingObserver _observer;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    _observer = SentryWidgetsBindingObserver(
      hub: hub,
      options: options,
    );

    // We don't need to call `WidgetsFlutterBinding.ensureInitialized()`
    // because `FlutterSentry.init` already calls it.
    WidgetsBinding.instance.addObserver(_observer);

    options.sdk.addIntegration('widgetsBindingIntegration');
  }

  @override
  void close() => WidgetsBinding.instance.removeObserver(_observer);
}

/// Loads the Android Image list for stack trace symbolication
class LoadAndroidImageListIntegration
    extends Integration<SentryFlutterOptions> {
  final MethodChannel _channel;

  LoadAndroidImageListIntegration(this._channel);

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    options.addEventProcessor(
      (event, {hint}) async {
        try {
          if (event.exception != null &&
              event.exception.stackTrace != null &&
              event.exception.stackTrace.frames != null) {
            final needsSymbolication = event.exception.stackTrace.frames
                .any((element) => 'native' == element.platform);

            // if there are no frames that require symbolication, we don't
            // load the debug image list.
            if (!needsSymbolication) {
              return event;
            }
          } else {
            return event;
          }

          // we call on every event because the loaded image list is cached
          // and it could be changed on the Native side.
          final imageList = List<Map<dynamic, dynamic>>.from(
            await _channel.invokeMethod('loadImageList'),
          );

          if (imageList.isEmpty) {
            return event;
          }

          final newDebugImages = <DebugImage>[];

          for (final item in imageList) {
            final codeFile = item['code_file'] as String;
            final codeId = item['code_id'] as String;
            final imageAddr = item['image_addr'] as String;
            final imageSize = item['image_size'] as int;
            final type = item['type'] as String;
            final debugId = item['debug_id'] as String;
            final debugFile = item['debug_file'] as String;

            final image = DebugImage(
              type: type,
              imageAddr: imageAddr,
              imageSize: imageSize,
              codeFile: codeFile,
              debugId: debugId,
              codeId: codeId,
              debugFile: debugFile,
            );
            newDebugImages.add(image);
          }

          final debugMeta = DebugMeta(images: newDebugImages);

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

    options.sdk.addIntegration('loadAndroidImageListIntegration');
  }
}

/// a PackageInfo wrapper to make it testable
typedef PackageLoader = Future<PackageInfo> Function();

/// an Integration that loads the Release version from Native Apps
/// or SENTRY_RELEASE and SENTRY_DIST variables
class LoadReleaseIntegration extends Integration<SentryFlutterOptions> {
  final PackageLoader _packageLoader;

  LoadReleaseIntegration(this._packageLoader);

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) async {
    try {
      if (!kIsWeb) {
        if (_packageLoader == null) {
          options.logger(SentryLevel.debug, 'Package loader is null.');
          return;
        }
        final packageInfo = await _packageLoader();
        final release =
            '${packageInfo.packageName}@${packageInfo.version}+${packageInfo.buildNumber}';
        options.logger(SentryLevel.debug, 'release: $release');

        options.release = release;
        options.dist = packageInfo.buildNumber;
      } else {
        // for non-mobile builds, we read the release and dist from the
        // system variables (SENTRY_RELEASE and SENTRY_DIST).
        options.release = const bool.hasEnvironment('SENTRY_RELEASE')
            ? const String.fromEnvironment('SENTRY_RELEASE')
            : options.release;
        options.dist = const bool.hasEnvironment('SENTRY_DIST')
            ? const String.fromEnvironment('SENTRY_DIST')
            : options.dist;
      }
    } catch (error) {
      options.logger(
          SentryLevel.error, 'Failed to load release and dist: $error');
    }

    options.sdk.addIntegration('loadReleaseIntegration');
  }
}
