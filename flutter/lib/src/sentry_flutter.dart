import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'span_frame_metrics_collector.dart';
import '../sentry_flutter.dart';
import 'event_processor/android_platform_exception_event_processor.dart';
import 'event_processor/flutter_exception_event_processor.dart';
import 'event_processor/platform_exception_event_processor.dart';
import 'event_processor/widget_event_processor.dart';
import 'frame_callback_handler.dart';
import 'integrations/connectivity/connectivity_integration.dart';
import 'integrations/screenshot_integration.dart';
import 'native/factory.dart';
import 'native/native_scope_observer.dart';
import 'native/sentry_native_binding.dart';
import 'profiling.dart';
import 'renderer/renderer.dart';

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
    @internal PlatformChecker? platformChecker,
    @internal RendererWrapper? rendererWrapper,
  }) async {
    final flutterOptions = SentryFlutterOptions();

    // ignore: invalid_use_of_internal_member
    sentrySetupStartTime ??= flutterOptions.clock();

    if (platformChecker != null) {
      flutterOptions.platformChecker = platformChecker;
    }
    if (rendererWrapper != null) {
      flutterOptions.rendererWrapper = rendererWrapper;
    }

    if (flutterOptions.platformChecker.hasNativeIntegration) {
      _native = createBinding(flutterOptions);
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
      flutterOptions,
      isOnErrorSupported,
    );
    for (final defaultIntegration in defaultIntegrations) {
      flutterOptions.addIntegration(defaultIntegration);
    }

    await _initDefaultValues(flutterOptions);

    await Sentry.init(
      (options) {
        assert(options == flutterOptions);
        return optionsConfiguration(options as SentryFlutterOptions);
      },
      appRunner: appRunner,
      // ignore: invalid_use_of_internal_member
      options: flutterOptions,
      // ignore: invalid_use_of_internal_member
      callAppRunnerInRunZonedGuarded: !isOnErrorSupported,
      // ignore: invalid_use_of_internal_member
      runZonedGuardedOnError: runZonedGuardedOnError,
    );

    if (_native != null) {
      // ignore: invalid_use_of_internal_member
      SentryNativeProfilerFactory.attachTo(Sentry.currentHub, _native!);
    }
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

    if (options.platformChecker.platform.isAndroid) {
      options.addEventProcessor(
        AndroidPlatformExceptionEventProcessor(options),
      );
    }

    options.addEventProcessor(PlatformExceptionEventProcessor());

    options.addPerformanceCollector(SpanFrameMetricsCollector(options));

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
      integrations.add(NativeAppStartIntegration(
        native,
        DefaultFrameCallbackHandler(),
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
    NativeAppStartIntegration.appStartEnd = appStartEnd;
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

  @internal
  static SentryNativeBinding? get native => _native;

  @internal
  static set native(SentryNativeBinding? value) => _native = value;

  static SentryNativeBinding? _native;
}
