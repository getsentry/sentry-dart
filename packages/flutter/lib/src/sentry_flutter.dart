// ignore_for_file: invalid_use_of_internal_member

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
import 'integrations/flutter_framework_feature_flag_integration.dart';
import 'integrations/frames_tracking_integration.dart';
import 'integrations/integrations.dart';
import 'integrations/native_app_start_handler.dart';
import 'integrations/replay_telemetry_integration.dart';
import 'integrations/screenshot_integration.dart';
import 'integrations/generic_app_start_integration.dart';
import 'integrations/thread_info_integration.dart';
import 'integrations/web_session_integration.dart';
import 'native/factory.dart';
import 'native/native_scope_observer.dart';
import 'native/sentry_native_binding.dart';
import 'profiling.dart';
import 'replay/integration.dart';
import 'screenshot/screenshot_support.dart';
import 'utils/platform_dispatcher_wrapper.dart';
import 'version.dart';
import 'view_hierarchy/view_hierarchy_integration.dart';
import 'web/javascript_transport.dart';

/// Configuration options callback
typedef FlutterOptionsConfiguration = FutureOr<void> Function(
    SentryFlutterOptions);

/// Sentry Flutter SDK main entry point
mixin SentryFlutter {
  /// Represents the time when the Sentry init set up has started.
  @internal
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
  // coverage:ignore-start
  static Future<void> init(
    FlutterOptionsConfiguration optionsConfiguration, {
    AppRunner? appRunner,
    @internal SentryFlutterOptions? options,
  }) async {
    SentryScreenshotWidget.reset();
    options ??= SentryFlutterOptions();

    sentrySetupStartTime ??= options.clock();

    if (options.platform.supportsNativeIntegration) {
      _native = createBinding(options);
    }

    final wrapper = PlatformDispatcherWrapper(PlatformDispatcher.instance);
    options.isMultiViewApp = wrapper.isMultiViewEnabled(options);

    // Flutter Web doesn't capture [Future] errors if using [PlatformDispatcher.onError] and not
    // the [runZonedGuarded].
    // likely due to https://github.com/flutter/flutter/issues/100277
    final isOnErrorSupported = !options.platform.isWeb;

    final bool isRootZone = options.runtimeChecker.isRootZone;

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
      options: options,
      callAppRunnerInRunZonedGuarded: useRunZonedGuarded,
      runZonedGuardedOnError: runZonedGuardedOnError,
    );

    if (_native != null) {
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
        if (options.platform.isWeb) {
          options.transport = JavascriptTransport(_native!, options);
        } else {
          options.transport = FileSystemTransport(_native!, options);
        }
      }
      if (!options.platform.isWeb) {
        options.addScopeObserver(NativeScopeObserver(_native!, options));
      }
    }

    options.addEventProcessor(FlutterEnricherEventProcessor(options));
    options.addEventProcessor(WidgetEventProcessor());
    options.addEventProcessor(UrlFilterEventProcessor(options));

    if (options.platform.isAndroid) {
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
    final platform = options.platform;

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

    // Adds Flutter framework feature flags.
    integrations.addFlutterFrameworkFeatureFlagIntegration();

    // The ordering here matters, as we'd like to first start the native integration.
    // That allow us to send events to the network and then the Flutter integrations.
    final native = _native;
    if (native != null) {
      // LoadReleaseIntegration needs to be executed after all the error handlers are in place.
      // Calling a MethodChannel might result in errors.
      // We also need to call this before the native sdk integrations so release is properly propagated.
      integrations.add(LoadReleaseIntegration());
      integrations.add(createSdkIntegration(native));
      integrations.add(createLoadDebugImagesIntegration(native));
      if (!platform.isWeb) {
        if (native.supportsLoadContexts) {
          integrations.add(LoadContextsIntegration(native));
        }
        integrations.add(FramesTrackingIntegration(native));
        if (platform.isIOS || platform.isAndroid || platform.isMacOS) {
          integrations.add(
            NativeAppStartIntegration(
              DefaultFrameCallbackHandler(),
              NativeAppStartHandler(native),
            ),
          );
        }
        integrations.add(ReplayIntegration(native));
      } else {
        // Updating sessions manually is only relevant for web
        // iOS & Android sessions are handled by the native SDKs directly
        //
        // Important:
        // Complete initialization of the integration depends on the SentryNavigatorObserver
        integrations.add(WebSessionIntegration(native));
      }
      options.enableDartSymbolication = false;
    }

    if (platform.isWeb || platform.isLinux || platform.isWindows) {
      integrations.add(GenericAppStartIntegration());
    }

    if (options.isScreenshotSupported) {
      integrations.add(ScreenshotIntegration());
    }

    if (platform.isWeb) {
      integrations.add(ConnectivityIntegration());
    }

    // works with Skia, CanvasKit and HTML renderer
    integrations.add(SentryViewHierarchyIntegration());

    integrations.add(DebugPrintIntegration());

    // Only add ReplayTelemetryIntegration on platforms that support replay
    if (native != null && native.supportsReplay) {
      integrations.add(ReplayTelemetryIntegration(native));
    }

    if (!platform.isWeb) {
      integrations.add(ThreadInfoIntegration());
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

  static void _setSdk(SentryFlutterOptions options) {
    // overwrite sdk info with current flutter sdk
    final sdk = SdkVersion(
      name: sdkName,
      version: sdkVersion,
      integrations: options.sdk.integrations,
      packages: options.sdk.packages,
      features: options.sdk.features,
    );
    sdk.addPackage('pub:sentry_flutter', sdkVersion);
    options.sdk = sdk;
  }
  // coverage:ignore-end

  @Deprecated(
      'Use reportFullyDisplayed() on a SentryDisplay instance instead. Read the TTFD documentation at https://docs.sentry.io/platforms/dart/guides/flutter/integrations/routing-instrumentation/#time-to-full-display.')
  static Future<void> reportFullyDisplayed() async {
    final options = Sentry.currentHub.options;
    if (options is SentryFlutterOptions) {
      try {
        final transactionId = options.timeToDisplayTracker.transactionId;
        return options.timeToDisplayTracker.reportFullyDisplayed(
          spanId: transactionId,
        );
      } catch (exception, stackTrace) {
        options.log(
          SentryLevel.error,
          'Error while reporting TTFD',
          exception: exception,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Returns the current display.
  ///
  /// Use it to report fully displayed for a widget when using the [SentryNavigatorObserver].
  ///
  /// Example:
  /// ```dart
  /// // At the start of async work
  /// final currentDisplay = SentryFlutter.currentDisplay;
  ///
  /// // After async work completes
  /// if (currentDisplay != null) {
  ///   currentDisplay.reportFullyDisplayed();
  /// }
  /// ```
  static SentryDisplay? currentDisplay({Hub? hub}) {
    hub ??= Sentry.currentHub;

    final options = hub.options;
    if (options is! SentryFlutterOptions) {
      return null;
    }
    final transactionId = options.timeToDisplayTracker.transactionId;
    if (transactionId == null) {
      hub.options.log(SentryLevel.error,
          'Could not process TTFD for screen ${SentryNavigatorObserver.currentRouteName} - transactionId should not be null');
      return null;
    }
    return SentryDisplay(transactionId, hub: hub);
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
    final options = Sentry.currentHub.options;
    if (!SentryScreenshotWidget.isMounted) {
      options.log(
        SentryLevel.debug,
        'SentryScreenshotWidget could not be found in the widget tree.',
      );
      return null;
    }
    final processors =
        options.eventProcessors.whereType<ScreenshotEventProcessor>();
    if (processors.isEmpty) {
      options.log(
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
    Sentry.currentHub.options.log(
      SentryLevel.debug,
      'Native integration is not available. Make sure SentryFlutter is initialized before accessing the $methodName API.',
    );
  }
}
