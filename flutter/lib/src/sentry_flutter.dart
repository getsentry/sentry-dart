import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../sentry_flutter.dart';
import 'event_processor/android_platform_exception_event_processor.dart';
import 'event_processor/flutter_enricher_event_processor.dart';
import 'event_processor/flutter_exception_event_processor.dart';
import 'event_processor/platform_exception_event_processor.dart';
import 'event_processor/screenshot_event_processor.dart';
import 'event_processor/url_filter/url_filter_event_processor.dart';
import 'event_processor/widget_event_processor.dart';
import 'file_system_transport.dart';
import 'flutter_exception_type_identifier.dart';
import 'frame_callback_handler.dart';
import 'integrations/connectivity/connectivity_integration.dart';
import 'integrations/frames_tracking_integration.dart';
import 'integrations/integrations.dart';
import 'integrations/native_app_start_handler.dart';
import 'integrations/screenshot_integration.dart';
import 'native/factory.dart';
import 'native/native_scope_observer.dart';
import 'native/sentry_native_binding.dart';
import 'profiling.dart';
import 'renderer/renderer.dart';
import 'replay/integration.dart';
import 'utils/platform_dispatcher_wrapper.dart';
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
    SentryScreenshotWidget.reset();
    options ??= SentryFlutterOptions();

    // ignore: invalid_use_of_internal_member
    sentrySetupStartTime ??= options.clock();

    if (options.platformChecker.hasNativeIntegration) {
      _native = createBinding(options);
    }

    final wrapper = PlatformDispatcherWrapper(PlatformDispatcher.instance);
    options.isMultiViewApp = wrapper.isMultiViewEnabled(options);

    // Flutter Web doesn't capture [Future] errors if using [PlatformDispatcher.onError] and not
    // the [runZonedGuarded].
    // likely due to https://github.com/flutter/flutter/issues/100277
    final bool isOnErrorSupported =
        !options.platformChecker.isWeb && wrapper.isOnErrorSupported(options);

    final bool isRootZone = options.platformChecker.isRootZone;

    // If onError is not supported and no custom zone exists, use runZonedGuarded to capture errors.
    final bool useRunZonedGuarded = !isOnErrorSupported && isRootZone;

    RunZonedGuardedOnError? runZonedGuardedOnError =
        useRunZonedGuarded ? _createRunZonedGuardedOnError() : null;

    // first step is to install the native integration and set default values,
    // so we are able to capture future errors.
    final defaultIntegrations = _createDefaultIntegrations(
      options,
      isOnErrorSupported,
    );
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
      callAppRunnerInRunZonedGuarded: useRunZonedGuarded,
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
      if (_native!.supportsCaptureEnvelope) {
        // Sentry's native web integration is only enabled when enableSentryJs=true.
        // Transport configuration happens in web_integration because the configuration
        // options aren't available until after the options callback executes.
        if (!options.platformChecker.isWeb) {
          options.transport = FileSystemTransport(_native!, options);
        }
      }
      if (!options.platformChecker.isWeb) {
        options.addScopeObserver(NativeScopeObserver(_native!));
      }
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
    final native = _native;
    if (native != null) {
      integrations.add(createSdkIntegration(native));
      if (!platformChecker.isWeb) {
        if (native.supportsLoadContexts) {
          integrations.add(LoadContextsIntegration(native));
        }
        integrations.add(LoadImageListIntegration(native));
        integrations.add(FramesTrackingIntegration(native));
        integrations.add(
          NativeAppStartIntegration(
            DefaultFrameCallbackHandler(),
            NativeAppStartHandler(native),
          ),
        );
        integrations.add(ReplayIntegration(native));
      }
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
  @Deprecated(
      'Will be removed in v9. This functionality will not be supported anymore.')
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
    // ignore: invalid_use_of_internal_member
    final options = Sentry.currentHub.options;
    if (options is SentryFlutterOptions) {
      try {
        return options.timeToDisplayTracker.reportFullyDisplayed();
      } catch (exception, stackTrace) {
        options.logger(
          SentryLevel.error,
          'Error while reporting TTFD',
          exception: exception,
          stackTrace: stackTrace,
        );
      }
    } else {
      return;
    }
  }

  /// Pauses the app hang tracking.
  /// Only for iOS and macOS.
  static Future<void> pauseAppHangTracking() async {
    if (_native == null) {
      _logNativeIntegrationNotAvailable("pauseAppHangTracking");
    } else {
      await _native!.pauseAppHangTracking();
    }
  }

  /// Resumes the app hang tracking.
  /// Only for iOS and macOS
  static Future<void> resumeAppHangTracking() async {
    if (_native == null) {
      _logNativeIntegrationNotAvailable("resumeAppHangTracking");
    } else {
      await _native!.resumeAppHangTracking();
    }
  }

  /// Uses [SentryScreenshotWidget] to capture the current screen as a
  /// [SentryAttachment].
  static Future<SentryAttachment?> captureScreenshot() async {
    // ignore: invalid_use_of_internal_member
    final options = Sentry.currentHub.options;
    if (!SentryScreenshotWidget.isMounted) {
      options.logger(
        SentryLevel.debug,
        'SentryScreenshotWidget could not be found in the widget tree.',
      );
      return null;
    }
    final processors =
        options.eventProcessors.whereType<ScreenshotEventProcessor>();
    if (processors.isEmpty) {
      options.logger(
        SentryLevel.debug,
        'ScreenshotEventProcessor could not be found.',
      );
      return null;
    }
    final processor = processors.first;
    final bytes = await processor.createScreenshot();
    if (bytes != null) {
      return SentryAttachment.fromScreenshotData(bytes);
    } else {
      return null;
    }
  }

  @internal
  static SentryNativeBinding? get native => _native;

  @internal
  static set native(SentryNativeBinding? value) => _native = value;

  static SentryNativeBinding? _native;

  /// Use `nativeCrash()` to crash the native implementation and test/debug the crash reporting for native code.
  /// This should not be used in production code.
  /// Only for Android, iOS and macOS
  static Future<void> nativeCrash() async {
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
