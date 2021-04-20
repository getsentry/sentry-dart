import 'package:flutter/foundation.dart' as foundation;
import 'package:sentry/sentry.dart';

/// This class adds options which are only availble in a Flutter environment.
/// Note that some of these options require native Sentry integration, which is
/// not available on all platforms.
class SentryFlutterOptions extends SentryOptions {
  SentryFlutterOptions({String? dsn}) : super(dsn: dsn) {
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

  int _autoSessionTrackingIntervalMillis = 30000;

  /// The session tracking interval in millis. This is the interval to end a
  /// session if the App goes to the background.
  /// See: [enableAutoSessionTracking]
  int get autoSessionTrackingIntervalMillis =>
      _autoSessionTrackingIntervalMillis;

  set autoSessionTrackingIntervalMillis(int value) {
    _autoSessionTrackingIntervalMillis =
        value >= 0 ? value : _autoSessionTrackingIntervalMillis;
  }

  /// Enable or disable ANR (Application Not Responding) Default is enabled Used by AnrIntegration.
  /// Available only for Android.
  /// Disabled by default as the stack trace most of the time is hanging on
  /// the MessageChannel from Flutter, but you can enable it if you have
  /// Java/Kotlin code as well.
  bool anrEnabled = false;

  int _anrTimeoutIntervalMillis = 5000;

  /// ANR Timeout internal in Millis Default is 5000 = 5s Used by AnrIntegration.
  /// Available only for Android.
  /// See: [anrEnabled]
  int get anrTimeoutIntervalMillis => _anrTimeoutIntervalMillis;

  set anrTimeoutIntervalMillis(int value) {
    _anrTimeoutIntervalMillis = value >= 0 ? value : _anrTimeoutIntervalMillis;
  }

  /// Enable or disable the Automatic breadcrumbs on the Native platforms (Android/iOS)
  /// Screen's lifecycle, App's lifecycle, System events, etc...
  ///
  /// If you only want to record breadcrumbs inside the Flutter environment
  /// consider using [useFlutterBreadcrumbTracking].
  bool enableAutoNativeBreadcrumbs = true;

  int _cacheDirSize = 30;

  /// The cache dir. size for capping the number of events Default is 30.
  /// Only available for Android.
  int get cacheDirSize => _cacheDirSize;

  set cacheDirSize(int value) {
    _cacheDirSize = value >= 0 ? value : _cacheDirSize;
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
  bool enableAppleOutOfMemoryTracking = false;

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
    // defaultTargetPlatform returns the platform this code currently runs on.
    // See https://api.flutter.dev/flutter/foundation/defaultTargetPlatform.html
    //
    // To test this method one can set
    // foundation.debugDefaultTargetPlatformOverride as one likes.
    configureBreadcrumbTrackingForPlatform(foundation.defaultTargetPlatform);
  }

  /// You should probably use [enableBreadcrumbTrackingForCurrentPlatform].
  /// This should only be used if you really want to override the default
  /// platform behavior.
  @foundation.visibleForTesting
  void configureBreadcrumbTrackingForPlatform(
      foundation.TargetPlatform platform) {
    // Bacause platform reports the Operating System and not if it is running
    // in a browser. So we have to check if this is Flutter for web.
    // See https://github.com/flutter/flutter/blob/c5a69b9b8ad186e9fce017fd4bfb8ce63f9f4d13/packages/flutter/lib/src/foundation/_platform_web.dart
    if (foundation.kIsWeb) {
      // Flutter for web has no native integration, just use the Flutter
      // integration.
      useFlutterBreadcrumbTracking();
      return;
    }

    // On all other platforms than web, we can just check the platform
    switch (platform) {
      case foundation.TargetPlatform.android:
      case foundation.TargetPlatform.iOS:
      case foundation.TargetPlatform.macOS:
        useNativeBreadcrumbTracking();
        break;
      case foundation.TargetPlatform.fuchsia:
      case foundation.TargetPlatform.linux:
      case foundation.TargetPlatform.windows:
        // These platforms have no native integration, so just use the Flutter
        // integration.
        useFlutterBreadcrumbTracking();
        break;
    }
  }

  // TODO: Scope observers, enableScopeSync
}
