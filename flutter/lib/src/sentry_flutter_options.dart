import 'package:sentry/sentry.dart';

// TODO: Scope observers, enableScopeSync

/// This class adds options which are only availble in a Flutter environment.
/// Note that some of these options require native Sentry integration, which is
/// not available on all platforms.
class SentryFlutterOptions extends SentryOptions {
  SentryFlutterOptions({String? dsn, PlatformChecker? checker})
      : super(dsn: dsn, checker: checker) {
    enableBreadcrumbTrackingForCurrentPlatform();
  }

  /// Enable or disable the Auto session tracking on the Native SDKs (Android/iOS)
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

  /// The session tracking interval in millis. This is the interval to end a
  /// session if the App goes to the background.
  /// See: [enableAutoSessionTracking]
  @Deprecated('Use autoSessionTrackingInterval instead')
  int get autoSessionTrackingIntervalMillis =>
      autoSessionTrackingInterval.inMilliseconds;

  @Deprecated('Use autoSessionTrackingInterval instead')
  set autoSessionTrackingIntervalMillis(int value) {
    autoSessionTrackingInterval = value >= 0
        ? Duration(milliseconds: value)
        : autoSessionTrackingInterval;
  }

  /// The session tracking interval. This is the interval to end a
  /// session if the App goes to the background.
  /// Default is 30 seconds/30000 milliseconds.
  /// See: [enableAutoSessionTracking]
  /// Always uses the given duration as a positiv timespan.
  Duration autoSessionTrackingInterval = Duration(milliseconds: 30000);

  /// Enable or disable ANR (Application Not Responding).
  /// Available only for Android.
  /// Disabled by default as the stack trace most of the time is hanging on
  /// the MessageChannel from Flutter, but you can enable it if you have
  /// Java/Kotlin code as well.
  bool anrEnabled = false;

  /// ANR Timeout internal in Millis Default is 5000 = 5s Used by AnrIntegration.
  /// Available only for Android.
  /// See: [anrEnabled]
  @Deprecated('Use anrTimeoutInterval instead')
  int get anrTimeoutIntervalMillis => anrTimeoutInterval.inMilliseconds;

  @Deprecated('Use anrTimeoutInterval instead')
  set anrTimeoutIntervalMillis(int value) {
    anrTimeoutInterval =
        value >= 0 ? Duration(milliseconds: value) : anrTimeoutInterval;
  }

  /// ANR Timeout internal. Default is 5000 milliseconds or 5 seconds.
  /// Used by Androids AnrIntegration. Available only on Android.
  /// See: [anrEnabled]
  /// Always uses the given duration as a positiv timespan.
  Duration anrTimeoutInterval = Duration(milliseconds: 5000);

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

  /// Enables Out of Memory Tracking for iOS and macCatalyst.
  /// See the following link for more information and possible restrictions:
  /// https://docs.sentry.io/platforms/apple/guides/ios/configuration/out-of-memory/
  bool enableOutOfMemoryTracking = true;

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
    if (platformChecker.hasNativeIntegration) {
      useNativeBreadcrumbTracking();
    } else {
      useFlutterBreadcrumbTracking();
    }
  }
}
