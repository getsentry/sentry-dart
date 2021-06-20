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
          'if you wish to capture silent errors',
        );
      }
    };
    FlutterError.onError = _integrationOnError;

    options.sdk.addIntegration('flutterErrorIntegration');
  }

  @override
  FutureOr<void> close() {
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
      _LoadContextsIntegrationEventProcessor(_channel, options),
    );
    options.sdk.addIntegration('loadContextsIntegration');
  }
}

class _LoadContextsIntegrationEventProcessor extends EventProcessor {
  _LoadContextsIntegrationEventProcessor(this._channel, this._options);

  final MethodChannel _channel;
  final SentryFlutterOptions _options;

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, {hint}) async {
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
        final integrations = List<String>.from(infos['integrations'] as List);
        final sdk = event.sdk ?? _options.sdk;
        integrations.forEach(sdk.addIntegration);
        event = event.copyWith(sdk: sdk);
      }

      if (infos['package'] != null) {
        final package = Map<String, String>.from(infos['package'] as Map);
        final sdk = event.sdk ?? _options.sdk;
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
    } catch (exception, stackTrace) {
      _options.logger(
        SentryLevel.error,
        'loadContextsIntegration failed',
        error: exception,
        stackTrace: stackTrace,
      );
    }
    return event;
  }
}

/// Enables Sentry's native SDKs (Android and iOS)
class NativeSdkIntegration extends Integration<SentryFlutterOptions> {
  NativeSdkIntegration(this._channel);

  final MethodChannel _channel;
  late SentryFlutterOptions _options;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) async {
    _options = options;
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
        'maxCacheItems': options.maxCacheItems,
        'sendDefaultPii': options.sendDefaultPii,
        'enableOutOfMemoryTracking': options.enableOutOfMemoryTracking,
      });

      options.sdk.addIntegration('nativeSdkIntegration');
    } catch (exception, stackTrace) {
      options.logger(
        SentryLevel.fatal,
        'nativeSdkIntegration failed to be installed',
        error: exception,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  FutureOr<void> close() async {
    try {
      await _channel.invokeMethod<void>('closeNativeSdk');
    } catch (exception, stackTrace) {
      _options.logger(
        SentryLevel.fatal,
        'nativeSdkIntegration failed to be closed',
        error: exception,
        stackTrace: stackTrace,
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
  FutureOr<void> close() {
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
      _LoadAndroidImageListIntegrationEventProcessor(_channel, options),
    );

    options.sdk.addIntegration('loadAndroidImageListIntegration');
  }
}

class _LoadAndroidImageListIntegrationEventProcessor extends EventProcessor {
  _LoadAndroidImageListIntegrationEventProcessor(this._channel, this._options);

  final MethodChannel _channel;
  final SentryFlutterOptions _options;

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, {hint}) async {
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
    } catch (exception, stackTrace) {
      _options.logger(
        SentryLevel.error,
        'loadImageList failed',
        error: exception,
        stackTrace: stackTrace,
      );
    }

    return event;
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
        var name = _cleanString(packageInfo.packageName);
        if (name.isEmpty) {
          // Not all platforms have a packageName.
          // If no packageName is available, use the appName instead.
          name = _cleanString(packageInfo.appName);
        }

        final version = _cleanString(packageInfo.version);
        final buildNumber = _cleanString(packageInfo.buildNumber);

        var release = name;
        if (version.isNotEmpty) {
          release = '$release@$version';
        }
        // At least windows sometimes does not have a buildNumber
        if (buildNumber.isNotEmpty) {
          release = '$release+$buildNumber';
        }

        options.logger(SentryLevel.debug, 'release: $release');

        options.release = options.release ?? release;
        if (buildNumber.isNotEmpty) {
          options.dist = options.dist ?? buildNumber;
        }
      }
    } catch (exception, stackTrace) {
      options.logger(
        SentryLevel.error,
        'Failed to load release and dist',
        error: exception,
        stackTrace: stackTrace,
      );
    }

    options.sdk.addIntegration('loadReleaseIntegration');
  }

  /// This method cleans the given string from characters which should not be
  /// used.
  /// For example https://docs.sentry.io/platforms/flutter/configuration/releases/#bind-the-version
  /// imposes some requirements. Also Windows uses some characters which
  /// should not be used.
  String _cleanString(String appName) {
    // Replace disallowed chars with an underscore '_'
    return appName
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll('\t', '_')
        .replaceAll('\r\n', '_')
        .replaceAll('\r', '_')
        .replaceAll('\n', '_')
        // replace Unicode NULL character with an empty string
        .replaceAll('\u{0000}', '');
  }
}
