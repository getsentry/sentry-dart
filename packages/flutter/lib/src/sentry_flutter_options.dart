import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart' as meta;
import 'package:sentry/sentry.dart';

import 'binding_wrapper.dart';
import 'event_processor/screenshot_event_processor.dart';
import 'navigation/time_to_display_tracker.dart';
import 'renderer/renderer.dart';
import 'screenshot/sentry_screenshot_quality.dart';
import 'sentry_privacy_options.dart';
import 'sentry_replay_options.dart';
import 'user_interaction/sentry_user_interaction_widget.dart';
import 'feedback/sentry_feedback_options.dart';

/// This class adds options which are only available in a Flutter environment.
/// Note that some of these options require native Sentry integration, which is
/// not available on all platforms.
class SentryFlutterOptions extends SentryOptions {
  SentryFlutterOptions({super.dsn, super.platform, super.checker}) {
    enableBreadcrumbTrackingForCurrentPlatform();
  }

  /// Initializes the Native SDKs on init.
  /// Set this to `false` if you have an existing native SDK and don't want to re-initialize.
  ///
  /// NOTE: Be careful and only use this if you know what you are doing.
  /// If you use this flag, make sure a native SDK is running before the Flutter Engine initializes or events might not be captured.
  /// Defaults to `true`.
  bool autoInitializeNativeSdk = true;

  /// Enable or disable reporting of used packages.
  bool reportPackages = true;

  /// Enable or disable the Auto session tracking on the Native SDKs (Android/iOS) and Web.
  ///
  /// Note: On web platforms, this requires using [SentryNavigatorObserver] to function properly.
  bool enableAutoSessionTracking = true;

  /// Enable or disable the Crash handling on the Native SDKs, e.g.,
  /// UncaughtExceptionHandler and [anrEnabled] for Android.
  ///
  /// SentryCrashIntegration (KSCrash) for iOS, turning this feature off on iOS
  /// has a side effect which is missing the Device's context, e.g.,
  /// App, Device and Operation System.
  ///
  /// Disabling this feature affects the [enableAutoSessionTracking]
  /// feature, as this is required to mark Sessions as Crashed.
  bool enableNativeCrashHandling = true;

  Duration _autoSessionTrackingInterval = Duration(milliseconds: 30000);

  /// The session tracking interval. This is the interval to end a
  /// session if the App goes to the background.
  /// Default is 30 seconds/30000 milliseconds.
  /// See: [enableAutoSessionTracking]
  /// Always uses the given duration as a positiv timespan.
  Duration get autoSessionTrackingInterval => _autoSessionTrackingInterval;

  set autoSessionTrackingInterval(Duration value) {
    assert(value > Duration.zero);
    _autoSessionTrackingInterval = value;
  }

  /// Enable or disable ANR (Application Not Responding).
  /// Available only for Android. Enabled by default.
  bool anrEnabled = true;

  Duration _anrTimeoutInterval = Duration(milliseconds: 5000);

  /// ANR Timeout internal. Default is 5000 milliseconds or 5 seconds.
  /// Used by Androids AnrIntegration. Available only on Android.
  /// See: [anrEnabled]
  /// Always uses the given duration as a positiv timespan.
  Duration get anrTimeoutInterval => _anrTimeoutInterval;

  set anrTimeoutInterval(Duration value) {
    assert(value > Duration.zero);
    _anrTimeoutInterval = value;
  }

  /// Enable or disable the Automatic breadcrumbs on the Native platforms (Android/iOS)
  /// Screen's lifecycle, App's lifecycle, System events, etc...
  ///
  /// If you only want to record breadcrumbs inside the Flutter environment
  /// consider using [useFlutterBreadcrumbTracking].
  bool enableAutoNativeBreadcrumbs = true;

  int _maxCacheItems = 30;

  /// Defines the maximal amount of offline stored events. Default is 30.
  /// Only available on Android, iOS and macOS.
  int get maxCacheItems => _maxCacheItems;

  set maxCacheItems(int value) {
    _maxCacheItems = value >= 0 ? value : _maxCacheItems;
  }

  /// Consider disabling [enableAutoNativeBreadcrumbs] if you
  /// enable this. Otherwise you might record app lifecycle events twice.
  /// Also consider using [enableBreadcrumbTrackingForCurrentPlatform]
  /// instead for more sensible defaults.
  ///
  /// Android:
  /// This is more or less equivalent to the [Activity Lifecycle](https://developer.android.com/guide/components/activities/activity-lifecycle).
  /// However because an Android Flutter application lives inside a single
  /// [Activity](https://developer.android.com/reference/android/app/Activity)
  /// this is an application wide lifecycle event.
  ///
  /// iOS:
  /// This is more or less equivalent to the [UIViewController](https://developer.apple.com/documentation/uikit/uiviewcontroller)s
  /// [lifecycle](https://developer.apple.com/documentation/uikit/app_and_environment/managing_your_app_s_life_cycle).
  /// However because an iOS Flutter application lives inside a single
  /// `UIViewController` this is an application wide lifecycle event.
  bool enableAppLifecycleBreadcrumbs = false;

  /// Consider disabling [enableAutoNativeBreadcrumbs] if you
  /// enable this. Otherwise you might record window metric events twice.
  /// Also consider using [enableBreadcrumbTrackingForCurrentPlatform]
  /// instead for more sensible defaults.
  bool enableWindowMetricBreadcrumbs = false;

  /// Consider disabling [enableAutoNativeBreadcrumbs] if you
  /// enable this. Otherwise you might record brightness change events twice.
  /// Also consider using [enableBreadcrumbTrackingForCurrentPlatform]
  /// instead for more sensible defaults.
  bool enableBrightnessChangeBreadcrumbs = false;

  /// Consider disabling [enableAutoNativeBreadcrumbs] if you
  /// enable this. Otherwise you might record text scale change events twice.
  /// Also consider using [enableBreadcrumbTrackingForCurrentPlatform]
  /// instead for more sensible defaults.
  bool enableTextScaleChangeBreadcrumbs = false;

  /// Consider disabling [enableAutoNativeBreadcrumbs] if you
  /// enable this. Otherwise you might record memory pressure events twice.
  /// Also consider using [enableBreadcrumbTrackingForCurrentPlatform]
  /// instead for more sensible defaults.
  bool enableMemoryPressureBreadcrumbs = false;

  /// By default, we don't report [FlutterErrorDetails.silent] errors,
  /// but you can by enabling this flag.
  /// See https://api.flutter.dev/flutter/foundation/FlutterErrorDetails/silent.html
  bool reportSilentFlutterErrors = false;

  /// (Web only) Events only occurring on these Urls will be handled and sent to sentry.
  /// If an empty list is used, the SDK will send all errors.
  /// `allowUrls` uses regex for the matching.
  ///
  /// If used on a platform other than Web, this setting will be ignored.
  List<String> allowUrls = [];

  /// (Web only) Events occurring on these Urls will be ignored and are not sent to sentry.
  /// If an empty list is used, the SDK will send all errors.
  /// `denyUrls` uses regex for the matching.
  /// In combination with `allowUrls` you can block subdomains of the domains listed in `allowUrls`.
  ///
  /// If used on a platform other than Web, this setting will be ignored.
  List<String> denyUrls = [];

  /// Enables Out of Memory Tracking for iOS and macCatalyst.
  /// See the following link for more information and possible restrictions:
  /// https://docs.sentry.io/platforms/apple/guides/ios/configuration/out-of-memory/
  bool enableWatchdogTerminationTracking = true;

  /// Enable scope sync from Java to NDK.
  /// Only available on Android.
  bool enableNdkScopeSync = true;

  /// Enable auto performance tracking by default.
  bool enableAutoPerformanceTracing = true;

  /// Automatically attaches a screenshot when capturing an error or exception.
  ///
  /// Requires adding the [SentryWidget] to the widget tree.
  /// Example:
  /// runApp(SentryWidget(child: App()));
  /// The [SentryWidget] has to be the root widget of the app.
  bool attachScreenshot = false;

  /// The quality of the attached screenshot
  SentryScreenshotQuality screenshotQuality = SentryScreenshotQuality.high;

  /// Sets a callback which is executed before capturing screenshots. Only
  /// relevant if `attachScreenshot` is set to true. When false is returned
  /// from the function, no screenshot will be attached.
  BeforeCaptureCallback? beforeCaptureScreenshot;

  /// Enable or disable automatic breadcrumbs for User interactions Using [Listener]
  ///
  /// Requires adding the [SentryUserInteractionWidget] to the widget tree.
  /// Example:
  /// runApp(SentryWidget(child: App()));
  bool enableUserInteractionBreadcrumbs = true;

  /// Enables the Auto instrumentation for user interaction tracing.
  ///
  /// Requires adding the [SentryUserInteractionWidget] to the widget tree.
  /// Example:
  /// runApp(SentryWidget(child: App()));
  bool enableUserInteractionTracing = true;

  /// Enable or disable the tracing of time to full display (TTFD).
  /// If `SentryFlutter.reportFullyDisplayed()` is not called within 30 seconds
  /// after the creation of the TTFD span, it will finish with the status [SpanStatus.deadlineExceeded].
  /// This feature requires using the [Routing Instrumentation](https://docs.sentry.io/platforms/flutter/integrations/routing-instrumentation/).
  bool enableTimeToFullDisplayTracing = false;

  @meta.internal
  late TimeToDisplayTracker timeToDisplayTracker = TimeToDisplayTracker(
    options: this,
  );

  /// Sets the Proguard uuid for Android platform.
  String? proguardUuid;

  @meta.internal
  late RendererWrapper rendererWrapper = RendererWrapper();

  @meta.internal
  bool isMultiViewApp = false;

  @meta.internal
  late MethodChannel methodChannel = const MethodChannel('sentry_flutter');

  /// Enables the View Hierarchy feature.
  ///
  /// Renders an ASCII representation of the entire view hierarchy of the
  /// application when an error happens and includes it as an attachment.
  @meta.experimental
  bool attachViewHierarchy = false;

  /// Sets a callback which is executed before capturing view hierarchy. Only
  /// relevant if `attachViewHierarchy` is set to true. When false is returned
  /// from the function, no view hierarchy will be attached.
  @meta.experimental
  BeforeCaptureCallback? beforeCaptureViewHierarchy;

  /// Enables collection of view hierarchy element identifiers.
  ///
  /// Identifiers are extracted from widget keys.
  /// Disable this flag if your widget keys contain sensitive data.
  ///
  /// Default: `true`
  bool reportViewHierarchyIdentifiers = true;

  /// When enabled, the SDK tracks when the application stops responding for a
  /// specific amount of time, See [appHangTimeoutInterval].
  /// Only available on iOS and macOS.
  bool enableAppHangTracking = true;

  /// The minimum amount of time an app should be unresponsive to be classified
  /// as an App Hanging. The actual amount may be a little longer. Avoid using
  /// values lower than 100ms, which may cause a lot of app hangs events being
  /// transmitted.
  /// Default to 2s.
  /// Only available on iOS and macOS.
  Duration appHangTimeoutInterval = Duration(seconds: 2);

  /// Connection timeout. This will only be synced to the Android native SDK.
  Duration connectionTimeout = Duration(seconds: 5);

  /// Read timeout. This will only be synced to the Android native SDK.
  Duration readTimeout = Duration(seconds: 5);

  /// Enable or disable Frames Tracking, which is used to report frame information
  /// for every [ISentrySpan].
  ///
  /// When enabled, the following metrics are reported for each span:
  /// - Slow frames: The number of frames that exceeded the expected frame duration. For most devices this will be around 16ms
  /// - Frozen frames: The number of frames that took more than 700ms to render, indicating a potential freeze or hang.
  /// - Total frames count: The total number of frames rendered during the span.
  /// - Frames delay: The delayed frame render duration of all frames.
  ///
  /// Read more about frames tracking here: https://develop.sentry.dev/sdk/performance/frames-delay/
  ///
  /// Defaults to `true`
  ///
  /// Supported platforms: `Android, iOS, macOS`
  ///
  /// Note: If you call `WidgetsFlutterBinding.ensureInitialized()` before `SentryFlutter.init()`,
  /// you must use `SentryWidgetsFlutterBinding.ensureInitialized()` instead.
  bool enableFramesTracking = true;

  /// Whether to synchronize the Dart trace to the native SDK.
  ///
  /// Allows native events to share the same trace as Dart events.
  ///
  /// Supported on Android and iOS/macOS.
  bool enableNativeTraceSync = true;

  /// Replay recording configuration.
  final replay = SentryReplayOptions();

  /// Privacy configuration for masking sensitive data in screenshots and Session Replay.
  /// Screen content masking is enabled by default.
  final privacy = SentryPrivacyOptions();

  /// Specifies the file system path to the Sentry database directory
  /// used by the Sentry Native SDK.
  ///
  /// ### Default
  /// If `null` (the default), the database directory is created at
  /// `.sentry-native` in the current working directory (CWD).
  ///
  /// ### Recommendation
  /// While relying on the default path may be sufficient during development,
  /// **it is strongly recommended** to provide an explicit path in production
  /// environments. Doing so ensures consistent and predictable behavior across
  /// deployments.
  ///
  /// ### Platform Support
  /// This option only applies to platforms that integrate the Sentry Native SDK
  /// directly:
  /// - **Linux (Desktop)**
  /// - **Windows (Desktop)**
  ///
  /// ### References
  /// For additional details, see:
  /// https://docs.sentry.io/platforms/native/configuration/options/#database-path
  String? nativeDatabasePath;

  /// By using this, you are disabling native [Breadcrumb] tracking and instead
  /// you are just tracking [Breadcrumb]s which result from events available
  /// in the current Flutter environment.
  void useFlutterBreadcrumbTracking() {
    enableAppLifecycleBreadcrumbs = true;
    enableWindowMetricBreadcrumbs = true;
    enableBrightnessChangeBreadcrumbs = true;
    enableTextScaleChangeBreadcrumbs = true;
    enableMemoryPressureBreadcrumbs = true;
    // This has currently no effect on Platforms other than Android and iOS
    // as there is no native integration for these platforms.
    // However this prevents accidentily recording
    // breadcrumbs twice, in case a native integration gets added.
    enableAutoNativeBreadcrumbs = false;
    // do not set enableNativeCrashHandling and co as it has nothing to do
    // with breadcrumbs
  }

  /// By using this, you are enabling native [Breadcrumb] tracking and disabling
  /// tracking [Breadcrumb]s which result from events available
  /// in the current Flutter environment.
  void useNativeBreadcrumbTracking() {
    enableAppLifecycleBreadcrumbs = false;
    enableWindowMetricBreadcrumbs = false;
    enableBrightnessChangeBreadcrumbs = false;
    enableTextScaleChangeBreadcrumbs = false;
    enableMemoryPressureBreadcrumbs = false;
    enableAutoNativeBreadcrumbs = true;
    // do not set enableNativeCrashHandling and co as they have nothing to do
    // with breadcrumbs
  }

  /// Automatically set sensible defaults for tracking [Breadcrumb]s.
  /// It considers the current platform and available native integrations.
  ///
  /// For platforms which have a native integration available this uses the
  /// native integration. On all other platforms it tracks events which are
  /// available in the Flutter environment. This way you get more detailed
  /// information where available.
  void enableBreadcrumbTrackingForCurrentPlatform() {
    if (platform.supportsNativeIntegration) {
      useNativeBreadcrumbTracking();
    } else {
      useFlutterBreadcrumbTracking();
    }
  }

  /// Setting this to a custom [BindingWrapper] allows you to use a custom [WidgetsBinding].
  @meta.experimental
  BindingWrapper bindingUtils = BindingWrapper();

  /// The sample rate for profiling traces in the range of 0.0 to 1.0.
  /// This is relative to tracesSampleRate - it is a ratio of profiled traces out of all sampled traces.
  /// At the moment, only apps targeting iOS and macOS are supported.
  @override
  @meta.experimental
  double? get profilesSampleRate {
    // ignore: invalid_use_of_internal_member
    return super.profilesSampleRate;
  }

  /// The sample rate for profiling traces in the range of 0.0 to 1.0.
  /// This is relative to tracesSampleRate - it is a ratio of profiled traces out of all sampled traces.
  /// At the moment, only apps targeting iOS and macOS are supported.
  @override
  @meta.experimental
  set profilesSampleRate(double? value) {
    // ignore: invalid_use_of_internal_member
    super.profilesSampleRate = value;
  }

  /// The [navigatorKey] is used to add information of the currently used locale to the contexts.
  GlobalKey<NavigatorState>? navigatorKey;

  // Override so we don't have to add `ignore` on each use.
  @meta.internal
  @override
  // ignore: invalid_use_of_internal_member
  bool get automatedTestMode => super.automatedTestMode;

  @meta.internal
  @override
  // ignore: invalid_use_of_internal_member
  set automatedTestMode(bool value) => super.automatedTestMode = value;

  /// If app lifecycle trace generation is enabled, this sets the duration the app must
  /// be in the background before a new trace id is generated upon resuming.
  ///
  /// Defaults to 30 seconds.
  @meta.internal
  Duration appInBackgroundTracingThreshold = Duration(seconds: 30);

  final _feedback = SentryFeedbackOptions();

  /// Options for the [SentryFeedbackWidget]
  SentryFeedbackOptions get feedback {
    // Added so we can track usage of the widget. This will only add the integration once, even if called multiple times.
    sdk.addIntegration('MobileFeedbackWidget');
    return _feedback;
  }
}

/// A callback which can be used to suppress capturing of screenshots.
/// It's called in [ScreenshotEventProcessor] if screenshots are enabled.
/// This gives more fine-grained control over when capturing should be performed,
/// e.g., only capture screenshots for fatal events or override any debouncing for important events.
///
/// Since capturing can be resource-intensive, the debounce parameter should be respected if possible.
///
/// Example:
/// ```dart
/// if (debounce) {
///   return false;
/// } else {
///   // check event and hint
/// }
/// ```
///
/// [event] is the event to be checked.
/// [hint] provides additional hints.
/// [debounce] indicates if capturing is marked for being debounced.
///
/// Returns `true` if capturing should be performed, otherwise `false`.
typedef BeforeCaptureCallback = FutureOr<bool> Function(
  SentryEvent event,
  Hint hint,
  bool debounce,
);
