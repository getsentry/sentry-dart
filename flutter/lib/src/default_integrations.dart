import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry/sentry.dart';
import 'sentry_flutter_options.dart';
import 'widgets_binding_observer.dart';

/// It is necessary to initialize Flutter method channels so that our plugin can
/// call into the native code.
class WidgetsFlutterBindingIntegration
    extends Integration<SentryFlutterOptions> {
  WidgetsFlutterBindingIntegration(
      [WidgetsBinding Function()? ensureInitialized])
      : _ensureInitialized =
            ensureInitialized ?? WidgetsFlutterBinding.ensureInitialized;

  final WidgetsBinding Function() _ensureInitialized;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    _ensureInitialized();
    options.sdk.addIntegration('widgetsFlutterBindingIntegration');
  }
}

/// Integration that capture errors on the [FlutterError.onError] handler.
///
/// Remarks:
///   - Most UI and layout related errors (such as
///     [these](https://flutter.dev/docs/testing/common-errors)) are AssertionErrors
///     and are stripped in release mode. See [Flutter build modes](https://flutter.dev/docs/testing/build-modes).
///     So they only get caught in debug mode.
class FlutterErrorIntegration extends Integration<SentryFlutterOptions> {
  /// Reference to the original handler.
  FlutterExceptionHandler? _defaultOnError;

  /// The error handler set by this integration.
  FlutterExceptionHandler? _integrationOnError;

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    _defaultOnError = FlutterError.onError;
    _integrationOnError = (FlutterErrorDetails errorDetails) async {
      dynamic exception = errorDetails.exception;

      options.logger(
        SentryLevel.debug,
        'Capture from onError $exception',
      );

      if (errorDetails.silent != true || options.reportSilentFlutterErrors) {
        // FlutterError doesn't crash the App.
        final mechanism = Mechanism(type: 'FlutterError', handled: true);
        final throwableMechanism = ThrowableMechanism(mechanism, exception);

        var event = SentryEvent(
          throwable: throwableMechanism,
          level: SentryLevel.fatal,
        );

        await hub.captureEvent(event, stackTrace: errorDetails.stack);

        // call original handler
        if (_defaultOnError != null) {
          _defaultOnError!(errorDetails);
        }

        // we don't call Zone.current.handleUncaughtError because we'd like
        // to set a specific mechanism for FlutterError.onError.
      } else {
        options.logger(
            SentryLevel.debug,
            'Error not captured due to [FlutterErrorDetails.silent], '
            'Enable [SentryFlutterOptions.reportSilentFlutterErrors] '
            'if you wish to capture silent errors');
      }
    };
    FlutterError.onError = _integrationOnError;

    options.sdk.addIntegration('flutterErrorIntegration');
  }

  @override
  void close() {
    /// Restore default if the integration error is still set.
    if (FlutterError.onError == _integrationOnError) {
      FlutterError.onError = _defaultOnError;
      _defaultOnError = null;
      _integrationOnError = null;
    }
    super.close();
  }
}

/// Load Device's Contexts from the iOS SDK.
///
/// This integration calls the iOS SDK via Message channel to load the
/// Device's contexts before sending the event back to the iOS SDK via
/// Message channel (already enriched with all the information).
///
/// The Device's contexts are:
/// App, Device and OS.
///
/// ps. This integration won't be run on Android because the Device's Contexts
/// is set on Android when the event is sent to the Android SDK via
/// the Message channel.
/// We intend to unify this behaviour in the future.
///
/// This integration is only executed on iOS & MacOS Apps.
class LoadContextsIntegration extends Integration<SentryFlutterOptions> {
  final MethodChannel _channel;

  LoadContextsIntegration(this._channel);

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) async {
    options.addEventProcessor(
      (event, {hint}) async {
        try {
          final infos = Map<String, dynamic>.from(
            await (_channel.invokeMethod('loadContexts')),
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
            sdk.addPackage(package['sdk_name']!, package['version']!);
            event = event.copyWith(sdk: sdk);
          }

          // on iOS, captureEnvelope does not call the beforeSend callback,
          // hence we need to add these tags here.
          if (event.sdk?.name == 'sentry.dart.flutter') {
            final tags = event.tags ?? {};
            tags['event.origin'] = 'flutter';
            tags['event.environment'] = 'dart';
            event = event.copyWith(tags: tags);
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
        'attachThreads': options.attachThreads,
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
        'sendDefaultPii': options.sendDefaultPii,
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
  SentryWidgetsBindingObserver? _observer;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    _observer = SentryWidgetsBindingObserver(
      hub: hub,
      options: options,
    );

    // We don't need to call `WidgetsFlutterBinding.ensureInitialized()`
    // because `WidgetsFlutterBindingIntegration` already calls it.
    // If the instance is not created, we skip it to keep going.
    final instance = WidgetsBinding.instance;
    if (instance != null) {
      instance.addObserver(_observer!);
      options.sdk.addIntegration('widgetsBindingIntegration');
    } else {
      options.logger(
        SentryLevel.error,
        'widgetsBindingIntegration failed to be installed',
      );
    }
  }

  @override
  void close() {
    final instance = WidgetsBinding.instance;
    if (instance != null && _observer != null) {
      instance.removeObserver(_observer!);
    }
  }
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
          if (event.exception != null && event.exception!.stackTrace != null) {
            final needsSymbolication = event.exception!.stackTrace!.frames
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
            await (_channel.invokeMethod('loadImageList')),
          );

          if (imageList.isEmpty) {
            return event;
          }

          final newDebugImages = <DebugImage>[];

          for (final item in imageList) {
            final codeFile = item['code_file'] as String?;
            final codeId = item['code_id'] as String?;
            final imageAddr = item['image_addr'] as String?;
            final imageSize = item['image_size'] as int?;
            final type = item['type'] as String;
            final debugId = item['debug_id'] as String?;
            final debugFile = item['debug_file'] as String?;

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

/// An [Integration] that loads the release version from native apps
class LoadReleaseIntegration extends Integration<SentryFlutterOptions> {
  final PackageLoader _packageLoader;

  LoadReleaseIntegration(this._packageLoader);

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) async {
    try {
      if (options.release == null || options.dist == null) {
        final packageInfo = await _packageLoader();
        final release =
            '${packageInfo.packageName}@${packageInfo.version}+${packageInfo.buildNumber}';
        options.logger(SentryLevel.debug, 'release: $release');

        options.release = options.release ?? release;
        options.dist = options.dist ?? packageInfo.buildNumber;
      }
    } catch (error) {
      options.logger(
          SentryLevel.error, 'Failed to load release and dist: $error');
    }

    options.sdk.addIntegration('loadReleaseIntegration');
  }
}
