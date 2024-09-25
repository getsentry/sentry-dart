import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../sentry_flutter.dart';
import 'event_processor/android_platform_exception_event_processor.dart';
import 'event_processor/flutter_enricher_event_processor.dart';
import 'event_processor/flutter_exception_event_processor.dart';
import 'event_processor/platform_exception_event_processor.dart';
import 'event_processor/url_filter/url_filter_event_processor.dart';
import 'event_processor/widget_event_processor.dart';
import 'file_system_transport.dart';
import 'flutter_exception_type_identifier.dart';
import 'frame_callback_handler.dart';
import 'integrations/connectivity/connectivity_integration.dart';
import 'integrations/integrations.dart';
import 'integrations/native_app_start_handler.dart';
import 'integrations/screenshot_integration.dart';
import 'native/factory.dart';
import 'native/native_scope_observer.dart';
import 'native/sentry_native_binding.dart';
import 'profiling.dart';
import 'renderer/renderer.dart';
import 'span_frame_metrics_collector.dart';
import 'version.dart';
import 'view_hierarchy/view_hierarchy_integration.dart';

/// Configuration options callback
typedef FlutterOptionsConfiguration = FutureOr<void> Function(
    SentryFlutterOptions);

/// Sentry Flutter SDK main entry point
mixin SentryFlutter {
  /// Represents the time when the Sentry init set up has started.
  @internal
  // ignore: invalid_use_of_internal_member
  static DateTime? sentrySetupStartTime;

  /// Initializes the Sentry Flutter SDK.
  ///
  /// Unlike [Sentry.init], this method creates the Flutter default integrations.
  ///
  /// [optionsConfiguration] is a callback that allows you to configure the Sentry
  /// options. The [SentryFlutterOptions] should not be adjusted anywhere else than
  /// during [init], so that's why they're not directly exposed outside of this method.
  ///
  /// You can use the static members of [Sentry] from within other packages without the
  /// need of initializing it in the package; as long as they have been already properly
  /// initialized in the application package.
  static Future<void> init(
    FlutterOptionsConfiguration optionsConfiguration, {
    AppRunner? appRunner,
    @internal SentryFlutterOptions? options,
  }) async {
    options ??= SentryFlutterOptions();

    // ignore: invalid_use_of_internal_member
    sentrySetupStartTime ??= options.clock();

    if (options.platformChecker.hasNativeIntegration) {
      _native = createBinding(options);
    }

    final platformDispatcher = PlatformDispatcher.instance;
    final wrapper = PlatformDispatcherWrapper(platformDispatcher);

    // Flutter Web don't capture [Future] errors if using [PlatformDispatcher.onError] and not
    // the [runZonedGuarded].
    // likely due to https://github.com/flutter/flutter/issues/100277
    final isOnErrorSupported = options.platformChecker.isWeb
        ? false
        : wrapper.isOnErrorSupported(options);

    final runZonedGuardedOnError =
        options.platformChecker.isWeb ? _createRunZonedGuardedOnError() : null;

    // first step is to install the native integration and set default values,
    // so we are able to capture future errors.
    final defaultIntegrations =
        _createDefaultIntegrations(options, isOnErrorSupported);
    for (final defaultIntegration in defaultIntegrations) {
      options.addIntegration(defaultIntegration);
    }

    await _initDefaultValues(options);

    await Sentry.init(
      (o) {
        assert(options == o);
        return optionsConfiguration(o as SentryFlutterOptions);
      },
      appRunner: appRunner,
      // ignore: invalid_use_of_internal_member
      options: options,
      // ignore: invalid_use_of_internal_member
      callAppRunnerInRunZonedGuarded: !isOnErrorSupported,
      // ignore: invalid_use_of_internal_member
      runZonedGuardedOnError: runZonedGuardedOnError,
    );

    if (_native != null) {
      // ignore: invalid_use_of_internal_member
      SentryNativeProfilerFactory.attachTo(Sentry.currentHub, _native!);
    }

    // Insert it at the start of the list, before the Dart Exceptions that are set in Sentry.init
    // so we can identify Flutter exceptions first.
    options.prependExceptionTypeIdentifier(FlutterExceptionTypeIdentifier());
  }

  static Future<void> _initDefaultValues(SentryFlutterOptions options) async {
    options.addEventProcessor(FlutterExceptionEventProcessor());

    // Not all platforms have a native integration.
    if (_native != null) {
      options.transport = FileSystemTransport(_native!, options);
      options.addScopeObserver(NativeScopeObserver(_native!));
    }

    options.addEventProcessor(FlutterEnricherEventProcessor(options));
    options.addEventProcessor(WidgetEventProcessor());
    options.addEventProcessor(UrlFilterEventProcessor(options));

    if (options.platformChecker.platform.isAndroid) {
      options.addEventProcessor(
        AndroidPlatformExceptionEventProcessor(options),
      );
    }

    options.addEventProcessor(PlatformExceptionEventProcessor());

    // Disabled for web, linux and windows until we can reliably get the display refresh rate
    if (options.platformChecker.platform.isAndroid ||
        options.platformChecker.platform.isIOS ||
        options.platformChecker.platform.isMacOS) {
      options.addPerformanceCollector(SpanFrameMetricsCollector(options));
    }

    _setSdk(options);
  }

  /// Install default integrations
  /// https://medium.com/flutter-community/error-handling-in-flutter-98fce88a34f0
  static List<Integration> _createDefaultIntegrations(
    SentryFlutterOptions options,
    bool isOnErrorSupported,
  ) {
    final integrations = <Integration>[];
    final platformChecker = options.platformChecker;

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
    final native = _native;
    if (native != null) {
      integrations.add(NativeSdkIntegration(native));
      integrations.add(LoadContextsIntegration(native));
      integrations.add(LoadImageListIntegration(native));
      options.enableDartSymbolication = false;
    }

    final renderer = options.rendererWrapper.getRenderer();
    if (!platformChecker.isWeb || renderer == FlutterRenderer.canvasKit) {
      integrations.add(ScreenshotIntegration());
    }

    if (platformChecker.isWeb) {
      integrations.add(ConnectivityIntegration());
    }

    // works with Skia, CanvasKit and HTML renderer
    integrations.add(SentryViewHierarchyIntegration());

    integrations.add(DebugPrintIntegration());

    // This is an Integration because we want to execute it after all the
    // error handlers are in place. Calling a MethodChannel might result
    // in errors.
    integrations.add(LoadReleaseIntegration());

    if (native != null) {
      integrations.add(
        NativeAppStartIntegration(
          DefaultFrameCallbackHandler(),
          NativeAppStartHandler(native),
        ),
      );
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
  /// [SentryFlutterOptions.autoAppStart] to false on init. The timeout duration
  /// for this to work is 10 seconds.
  static void setAppStartEnd(DateTime appStartEnd) {
    // ignore: invalid_use_of_internal_member
    final integrations = Sentry.currentHub.options.integrations
        .whereType<NativeAppStartIntegration>();
    for (final integration in integrations) {
      integration.appStartEnd = appStartEnd;
    }
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

  /// Reports the time it took for the screen to be fully displayed.
  /// This requires the [SentryFlutterOptions.enableTimeToFullDisplayTracing] option to be set to `true`.
  static Future<void> reportFullyDisplayed() async {
    return SentryNavigatorObserver.timeToDisplayTracker?.reportFullyDisplayed();
  }

  /// Pauses the app hang tracking.
  /// Only for iOS and macOS.
  static Future<void> pauseAppHangTracking() {
    if (_native == null) {
      _logNativeIntegrationNotAvailable("pauseAppHangTracking");
      return Future<void>.value();
    }
    return _native!.pauseAppHangTracking();
  }

  /// Resumes the app hang tracking.
  /// Only for iOS and macOS
  static Future<void> resumeAppHangTracking() {
    if (_native == null) {
      _logNativeIntegrationNotAvailable("resumeAppHangTracking");
      return Future<void>.value();
    }
    return _native!.resumeAppHangTracking();
  }

  @internal
  static SentryNativeBinding? get native => _native;

  @internal
  static set native(SentryNativeBinding? value) => _native = value;

  static SentryNativeBinding? _native;

  /// Use `nativeCrash()` to crash the native implementation and test/debug the crash reporting for native code.
  /// This should not be used in production code.
  /// Only for Android, iOS and macOS
  static Future<void> nativeCrash() {
    if (_native == null) {
      _logNativeIntegrationNotAvailable("nativeCrash");
      return Future<void>.value();
    }
    return _native!.nativeCrash();
  }

  static void _logNativeIntegrationNotAvailable(String methodName) {
    // ignore: invalid_use_of_internal_member
    Sentry.currentHub.options.logger(
      SentryLevel.debug,
      'Native integration is not available. Make sure SentryFlutter is initialized before accessing the $methodName API.',
    );
  }
}
