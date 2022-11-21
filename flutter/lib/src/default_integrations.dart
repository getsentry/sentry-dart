import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry/sentry.dart';
import 'binding_utils.dart';
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
      final exception = errorDetails.exception;

      options.logger(
        SentryLevel.debug,
        'Capture from onError $exception',
      );

      if (errorDetails.silent != true || options.reportSilentFlutterErrors) {
        final context = errorDetails.context?.toDescription();

        final collector = errorDetails.informationCollector?.call() ?? [];
        final information =
            (StringBuffer()..writeAll(collector, '\n')).toString();
        // errorDetails.library defaults to 'Flutter framework' even though it
        // is nullable. We do null checks anyway, just to be sure.
        final library = errorDetails.library;

        final flutterErrorDetails = <String, String>{
          // This is a message which should make sense if written after the
          // word `thrown`:
          // https://api.flutter.dev/flutter/foundation/FlutterErrorDetails/context.html
          if (context != null) 'context': 'thrown $context',
          if (collector.isNotEmpty) 'information': information,
          if (library != null) 'library': library,
        };

        options.logger(
          SentryLevel.error,
          errorDetails.toStringShort(),
          logger: 'sentry.flutterError',
          exception: exception,
          stackTrace: errorDetails.stack,
        );

        // FlutterError doesn't crash the App.
        final mechanism = Mechanism(
          type: 'FlutterError',
          handled: true,
          data: {
            if (flutterErrorDetails.isNotEmpty)
              'hint':
                  'See "flutter_error_details" down below for more information'
          },
        );
        final throwableMechanism = ThrowableMechanism(mechanism, exception);

        var event = SentryEvent(
          throwable: throwableMechanism,
          level: SentryLevel.fatal,
          contexts: flutterErrorDetails.isNotEmpty
              ? (Contexts()..['flutter_error_details'] = flutterErrorDetails)
              : null,
        );

        await hub.captureEvent(event,
            stackTrace: errorDetails.stack,
            hint: Hint.fromMap({'errorDetails': errorDetails}));
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
      // Call original handler, regardless of `errorDetails.silent` or
      // `reportSilentFlutterErrors`. This ensures, that we don't swallow
      // messages.
      if (_defaultOnError != null) {
        _defaultOnError!(errorDetails);
      }
    };
    FlutterError.onError = _integrationOnError;

    options.sdk.addIntegration('flutterErrorIntegration');
  }

  @override
  FutureOr<void> close() async {
    /// Restore default if the integration error is still set.
    if (FlutterError.onError == _integrationOnError) {
      FlutterError.onError = _defaultOnError;
      _defaultOnError = null;
      _integrationOnError = null;
    }
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
      final contextsMap = infos['contexts'] as Map?;
      if (contextsMap != null && contextsMap.isNotEmpty) {
        final contexts = Contexts.fromJson(
          Map<String, dynamic>.from(contextsMap),
        );
        final eventContexts = event.contexts.clone();

        contexts.forEach(
          (key, dynamic value) {
            if (value != null) {
              final currentValue = eventContexts[key];
              if (key == SentryRuntime.listType) {
                contexts.runtimes.forEach(eventContexts.addRuntime);
              } else if (currentValue == null) {
                eventContexts[key] = value;
              } else {
                if (key == SentryOperatingSystem.type &&
                    currentValue is SentryOperatingSystem &&
                    value is SentryOperatingSystem) {
                  final osMap = {...value.toJson(), ...currentValue.toJson()};
                  final os = SentryOperatingSystem.fromJson(osMap);
                  eventContexts[key] = os;
                }
              }
            }
          },
        );
        event = event.copyWith(contexts: eventContexts);
      }

      final tagsMap = infos['tags'] as Map?;
      if (tagsMap != null && tagsMap.isNotEmpty) {
        final tags = event.tags ?? {};
        final newTags = Map<String, String>.from(tagsMap);

        for (final tag in newTags.entries) {
          if (!tags.containsKey(tag.key)) {
            tags[tag.key] = tag.value;
          }
        }
        event = event.copyWith(tags: tags);
      }

      final extraMap = infos['extra'] as Map?;
      if (extraMap != null && extraMap.isNotEmpty) {
        final extras = event.extra ?? {};
        final newExtras = Map<String, dynamic>.from(extraMap);

        for (final extra in newExtras.entries) {
          if (!extras.containsKey(extra.key)) {
            extras[extra.key] = extra.value;
          }
        }
        event = event.copyWith(extra: extras);
      }

      final userMap = infos['user'] as Map?;
      if (event.user == null && userMap != null && userMap.isNotEmpty) {
        final user = Map<String, dynamic>.from(userMap);
        event = event.copyWith(user: SentryUser.fromJson(user));
      }

      final distString = infos['dist'] as String?;
      if (event.dist == null && distString != null) {
        event = event.copyWith(dist: distString);
      }

      final environmentString = infos['environment'] as String?;
      if (event.environment == null && environmentString != null) {
        event = event.copyWith(environment: environmentString);
      }

      final fingerprintList = infos['fingerprint'] as List?;
      if (fingerprintList != null && fingerprintList.isNotEmpty) {
        final eventFingerprints = event.fingerprint ?? [];
        final newFingerprint = List<String>.from(fingerprintList);

        for (final fingerprint in newFingerprint) {
          if (!eventFingerprints.contains(fingerprint)) {
            eventFingerprints.add(fingerprint);
          }
        }
        event = event.copyWith(fingerprint: eventFingerprints);
      }

      final levelString = infos['level'] as String?;
      if (event.level == null && levelString != null) {
        event = event.copyWith(level: SentryLevel.fromName(levelString));
      }

      final breadcrumbsList = infos['breadcrumbs'] as List?;
      if (breadcrumbsList != null && breadcrumbsList.isNotEmpty) {
        final breadcrumbs = event.breadcrumbs ?? [];
        final newBreadcrumbs = List<Map>.from(breadcrumbsList);

        for (final breadcrumb in newBreadcrumbs) {
          final newBreadcrumb = Map<String, dynamic>.from(breadcrumb);
          final crumb = Breadcrumb.fromJson(newBreadcrumb);
          breadcrumbs.add(crumb);
        }

        breadcrumbs.sort((a, b) {
          return a.timestamp.compareTo(b.timestamp);
        });

        event = event.copyWith(breadcrumbs: breadcrumbs);
      }

      final integrationsList = infos['integrations'] as List?;
      if (integrationsList != null && integrationsList.isNotEmpty) {
        final integrations = List<String>.from(integrationsList);
        final sdk = event.sdk ?? _options.sdk;

        for (final integration in integrations) {
          if (!sdk.integrations.contains(integration)) {
            sdk.addIntegration(integration);
          }
        }

        event = event.copyWith(sdk: sdk);
      }

      final packageMap = infos['package'] as Map?;
      if (packageMap != null && packageMap.isNotEmpty) {
        final package = Map<String, String>.from(packageMap);
        final sdk = event.sdk ?? _options.sdk;

        final name = package['sdk_name'];
        final version = package['version'];
        if (name != null &&
            version != null &&
            !sdk.packages.any((element) =>
                element.name == name && element.version == version)) {
          sdk.addPackage(name, version);
        }

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
        exception: exception,
        stackTrace: stackTrace,
      );
    }
    return event;
  }
}

/// Enables Sentry's native SDKs (Android and iOS) with options.
class NativeSdkIntegration extends Integration<SentryFlutterOptions> {
  NativeSdkIntegration(this._channel);

  final MethodChannel _channel;
  SentryFlutterOptions? _options;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) async {
    _options = options;
    if (!options.autoInitializeNativeSdk) {
      return;
    }
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
            options.autoSessionTrackingInterval.inMilliseconds,
        'dist': options.dist,
        'integrations': options.sdk.integrations,
        'packages':
            options.sdk.packages.map((e) => e.toJson()).toList(growable: false),
        'diagnosticLevel': options.diagnosticLevel.name,
        'maxBreadcrumbs': options.maxBreadcrumbs,
        'anrEnabled': options.anrEnabled,
        'anrTimeoutIntervalMillis': options.anrTimeoutInterval.inMilliseconds,
        'enableAutoNativeBreadcrumbs': options.enableAutoNativeBreadcrumbs,
        'maxCacheItems': options.maxCacheItems,
        'sendDefaultPii': options.sendDefaultPii,
        'enableOutOfMemoryTracking': options.enableOutOfMemoryTracking,
        'enableNdkScopeSync': options.enableNdkScopeSync,
        'enableAutoPerformanceTracking': options.enableAutoPerformanceTracking,
        'sendClientReports': options.sendClientReports,
      });

      options.sdk.addIntegration('nativeSdkIntegration');
    } catch (exception, stackTrace) {
      options.logger(
        SentryLevel.fatal,
        'nativeSdkIntegration failed to be installed',
        exception: exception,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  FutureOr<void> close() async {
    final options = _options;
    if (options != null && !options.autoInitializeNativeSdk) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('closeNativeSdk');
    } catch (exception, stackTrace) {
      _options?.logger(
        SentryLevel.fatal,
        'nativeSdkIntegration failed to be closed',
        exception: exception,
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
    final instance = BindingUtils.getWidgetsBindingInstance();
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
    final instance = BindingUtils.getWidgetsBindingInstance();
    if (instance != null && _observer != null) {
      instance.removeObserver(_observer!);
    }
  }
}

/// Loads the native debug image list for stack trace symbolication.
class LoadImageListIntegration extends Integration<SentryFlutterOptions> {
  final MethodChannel _channel;

  LoadImageListIntegration(this._channel);

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    options.addEventProcessor(
      _LoadImageListIntegrationEventProcessor(_channel, options),
    );

    options.sdk.addIntegration('loadImageListIntegration');
  }
}

extension _NeedsSymbolication on SentryEvent {
  bool needsSymbolication() {
    if (this is SentryTransaction) return false;
    final frames = exceptions?.first.stackTrace?.frames;
    if (frames == null) return false;
    return frames.any((frame) => 'native' == frame.platform);
  }
}

class _LoadImageListIntegrationEventProcessor extends EventProcessor {
  _LoadImageListIntegrationEventProcessor(this._channel, this._options);

  final MethodChannel _channel;
  final SentryFlutterOptions _options;

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, {hint}) async {
    if (event.needsSymbolication()) {
      try {
        // we call on every event because the loaded image list is cached
        // and it could be changed on the Native side.
        final imageList = List<Map<dynamic, dynamic>>.from(
          await _channel.invokeMethod('loadImageList'),
        );
        return copyWithDebugImages(event, imageList);
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'loadImageList failed',
          exception: exception,
          stackTrace: stackTrace,
        );
      }
    }

    return event;
  }

  static SentryEvent copyWithDebugImages(
      SentryEvent event, List<Object?> imageList) {
    if (imageList.isEmpty) {
      return event;
    }

    final newDebugImages = <DebugImage>[];
    for (final obj in imageList) {
      final jsonMap = Map<String, dynamic>.from(obj as Map<dynamic, dynamic>);
      final image = DebugImage.fromJson(jsonMap);
      newDebugImages.add(image);
    }

    return event.copyWith(debugMeta: DebugMeta(images: newDebugImages));
  }
}

/// An [Integration] that loads the release version from native apps
class LoadReleaseIntegration extends Integration<SentryFlutterOptions> {
  LoadReleaseIntegration();

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) async {
    try {
      if (options.release == null || options.dist == null) {
        final packageInfo = await PackageInfo.fromPlatform();
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
        exception: exception,
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
