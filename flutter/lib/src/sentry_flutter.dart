import 'dart:async';
import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import '../sentry_flutter.dart';
import 'event_processor/android_platform_exception_event_processor.dart';
import 'event_processor/flutter_exception_event_processor.dart';
import 'event_processor/platform_exception_event_processor.dart';
import 'integrations/screenshot_integration.dart';
import 'native/native_scope_observer.dart';
import 'renderer/renderer.dart';
import 'native/sentry_native.dart';
import 'native/sentry_native_channel.dart';

import 'integrations/integrations.dart';
import 'event_processor/flutter_enricher_event_processor.dart';

import 'file_system_transport.dart';

import 'version.dart';
import 'view_hierarchy/view_hierarchy_integration.dart';

/// Configuration options callback
typedef FlutterOptionsConfiguration = FutureOr<void> Function(
    SentryFlutterOptions);

/// Sentry Flutter SDK main entry point
mixin SentryFlutter {
  static const _channel = MethodChannel('sentry_flutter');

  static Future<void> init(
    FlutterOptionsConfiguration optionsConfiguration, {
    AppRunner? appRunner,
    @internal MethodChannel channel = _channel,
    @internal PlatformChecker? platformChecker,
    @internal RendererWrapper? rendererWrapper,
  }) async {
    final flutterOptions = SentryFlutterOptions();

    if (platformChecker != null) {
      flutterOptions.platformChecker = platformChecker;
    }
    if (rendererWrapper != null) {
      flutterOptions.rendererWrapper = rendererWrapper;
    }

    if (flutterOptions.platformChecker.hasNativeIntegration) {
      // Set a default native channel to the singleton SentryNative instance.
      SentryNative().nativeChannel =
          SentryNativeChannel(channel, flutterOptions);
    }

    final platformDispatcher = PlatformDispatcher.instance;
    final wrapper = PlatformDispatcherWrapper(platformDispatcher);

    // Flutter Web don't capture [Future] errors if using [PlatformDispatcher.onError] and not
    // the [runZonedGuarded].
    // likely due to https://github.com/flutter/flutter/issues/100277
    final isOnErrorSupported = flutterOptions.platformChecker.isWeb
        ? false
        : wrapper.isOnErrorSupported(flutterOptions);

    final runZonedGuardedOnError = flutterOptions.platformChecker.isWeb
        ? _createRunZonedGuardedOnError()
        : null;

    // first step is to install the native integration and set default values,
    // so we are able to capture future errors.
    final defaultIntegrations = _createDefaultIntegrations(
      channel,
      flutterOptions,
      isOnErrorSupported,
    );
    for (final defaultIntegration in defaultIntegrations) {
      flutterOptions.addIntegration(defaultIntegration);
    }

    await _initDefaultValues(flutterOptions, channel);

    await Sentry.init(
      (options) async {
        await optionsConfiguration(options as SentryFlutterOptions);
      },
      appRunner: appRunner,
      // ignore: invalid_use_of_internal_member
      options: flutterOptions,
      // ignore: invalid_use_of_internal_member
      callAppRunnerInRunZonedGuarded: !isOnErrorSupported,
      // ignore: invalid_use_of_internal_member
      runZonedGuardedOnError: runZonedGuardedOnError,
    );
  }

  static Future<void> _initDefaultValues(
    SentryFlutterOptions options,
    MethodChannel channel,
  ) async {
    options.addEventProcessor(FlutterExceptionEventProcessor());

    // Not all platforms have a native integration.
    if (options.platformChecker.hasNativeIntegration) {
      options.transport = FileSystemTransport(channel, options);
      options.addScopeObserver(NativeScopeObserver(SentryNative()));
    }

    var flutterEventProcessor = FlutterEnricherEventProcessor(options);
    options.addEventProcessor(flutterEventProcessor);

    if (options.platformChecker.platform.isAndroid) {
      options
          .addEventProcessor(AndroidPlatformExceptionEventProcessor(options));
    }

    options.addEventProcessor(PlatformExceptionEventProcessor());

    _setSdk(options);
  }

  /// Install default integrations
  /// https://medium.com/flutter-community/error-handling-in-flutter-98fce88a34f0
  static List<Integration> _createDefaultIntegrations(
    MethodChannel channel,
    SentryFlutterOptions options,
    bool isOnErrorSupported,
  ) {
    final integrations = <Integration>[];
    final platformChecker = options.platformChecker;
    final platform = platformChecker.platform;

    // Will call WidgetsFlutterBinding.ensureInitialized() before all other integrations.
    integrations.add(WidgetsFlutterBindingIntegration());

    // Use PlatformDispatcher.onError instead of zones.
    if (isOnErrorSupported) {
      integrations.add(OnErrorIntegration());
    }

    // Will catch any errors that may occur in the Flutter framework itself.
    integrations.add(FlutterErrorIntegration());

    // This tracks Flutter application events, such as lifecycle events.
    integrations.add(WidgetsBindingIntegration());

    // The ordering here matters, as we'd like to first start the native integration.
    // That allow us to send events to the network and then the Flutter integrations.
    // Flutter Web doesn't need that, only Android and iOS.
    if (platformChecker.hasNativeIntegration) {
      integrations.add(NativeSdkIntegration(channel));
    }

    // Will enrich events with device context, native packages and integrations
    if (platformChecker.hasNativeIntegration &&
        !platformChecker.isWeb &&
        (platform.isIOS || platform.isMacOS)) {
      integrations.add(LoadContextsIntegration(channel));
    }

    if (platformChecker.hasNativeIntegration &&
        !platformChecker.isWeb &&
        (platform.isAndroid || platform.isIOS || platform.isMacOS)) {
      integrations.add(LoadImageListIntegration(channel));
    }
    final renderer = options.rendererWrapper.getRenderer();
    if (renderer == FlutterRenderer.skia ||
        renderer == FlutterRenderer.canvasKit) {
      integrations.add(ScreenshotIntegration());
    }

    // works with Skia, CanvasKit and HTML renderer
    integrations.add(SentryViewHierarchyIntegration());

    integrations.add(DebugPrintIntegration());

    // This is an Integration because we want to execute it after all the
    // error handlers are in place. Calling a MethodChannel might result
    // in errors.
    integrations.add(LoadReleaseIntegration());

    if (platformChecker.hasNativeIntegration) {
      integrations.add(NativeAppStartIntegration(
        SentryNative(),
        () {
          try {
            /// Flutter >= 2.12 throws if SchedulerBinding.instance isn't initialized.
            return SchedulerBinding.instance;
          } catch (_) {}
          return null;
        },
      ));
    }
    return integrations;
  }

  static RunZonedGuardedOnError _createRunZonedGuardedOnError() {
    return (Object error, StackTrace stackTrace) async {
      final errorDetails = FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
      );
      FlutterError.dumpErrorToConsole(errorDetails, forceReport: true);
    };
  }

  /// Manually set when your app finished startup. Make sure to set
  /// [SentryFlutterOptions.autoAppStart] to false on init.
  static void setAppStartEnd(DateTime appStartEnd) {
    SentryNative().appStartEnd = appStartEnd;
  }

  static void _setSdk(SentryFlutterOptions options) {
    // overwrite sdk info with current flutter sdk
    final sdk = SdkVersion(
      name: sdkName,
      version: sdkVersion,
      integrations: options.sdk.integrations,
      packages: options.sdk.packages,
    );
    sdk.addPackage('pub:sentry_flutter', sdkVersion);
    options.sdk = sdk;
  }
}
