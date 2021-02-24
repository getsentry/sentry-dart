import 'package:flutter/foundation.dart' as foundation;
import 'package:sentry/sentry.dart';

/// This class adds options which are only availble in a Flutter environment.
/// Note that some of these options require native Sentry integration, which is
/// not available on all platforms.
class SentryFlutterOptions extends SentryOptions {
  SentryFlutterOptions() : super();

  bool _enableAutoSessionTracking = true;

  /// Enable or disable the Auto session tracking on the Native SDKs (Android/iOS)
  bool get enableAutoSessionTracking => _enableAutoSessionTracking;

  set enableAutoSessionTracking(bool value) {
    assert(value != null);
    _enableAutoSessionTracking = value ?? _enableAutoSessionTracking;
  }

  bool _enableNativeCrashHandling = true;

  /// Enable or disable the Crash handling on the Native SDKs
  /// eg UncaughtExceptionHandler and [anrEnabled] for Android
  ///
  /// Available only for Android.
  bool get enableNativeCrashHandling => _enableNativeCrashHandling;

  set enableNativeCrashHandling(bool value) {
    assert(value != null);
    _enableNativeCrashHandling = value ?? _enableNativeCrashHandling;
  }

  int _autoSessionTrackingIntervalMillis = 30000;

  /// The session tracking interval in millis. This is the interval to end a
  /// session if the App goes to the background.
  /// See: [enableAutoSessionTracking]
  int get autoSessionTrackingIntervalMillis =>
      _autoSessionTrackingIntervalMillis;

  set autoSessionTrackingIntervalMillis(int value) {
    assert(value != null);
    _autoSessionTrackingIntervalMillis = (value != null && value >= 0)
        ? value
        : _autoSessionTrackingIntervalMillis;
  }

  bool _anrEnabled = false;

  /// Enable or disable ANR (Application Not Responding) Default is enabled Used by AnrIntegration.
  /// Available only for Android.
  /// Disabled by default as the stack trace most of the time is hanging on
  /// the MessageChannel from Flutter, but you can enable it if you have
  /// Java/Kotlin code as well.
  bool get anrEnabled => _anrEnabled;

  set anrEnabled(bool value) {
    assert(value != null);
    _anrEnabled = value ?? _anrEnabled;
  }

  int _anrTimeoutIntervalMillis = 5000;

  /// ANR Timeout internal in Millis Default is 5000 = 5s Used by AnrIntegration.
  /// Available only for Android.
  /// See: [anrEnabled]
  int get anrTimeoutIntervalMillis => _anrTimeoutIntervalMillis;

  set anrTimeoutIntervalMillis(int value) {
    assert(value != null);
    _anrTimeoutIntervalMillis =
        (value != null && value >= 0) ? value : _anrTimeoutIntervalMillis;
  }

  bool _enableAutoNativeBreadcrumbs = true;

  /// Enable or disable the Automatic breadcrumbs on the Native platforms (Android/iOS)
  /// Screen's lifecycle, App's lifecycle, System events, etc...
  ///
  /// If you only want to record breadcrumbs inside the Flutter environment
  /// consider using [useFlutterBreadcrumbTracking].
  bool get enableAutoNativeBreadcrumbs => _enableAutoNativeBreadcrumbs;

  set enableAutoNativeBreadcrumbs(bool value) {
    assert(value != null);
    _enableAutoNativeBreadcrumbs = value ?? _enableAutoNativeBreadcrumbs;
  }

  int _cacheDirSize = 30;

  /// The cache dir. size for capping the number of events Default is 30.
  /// Only available for Android.
  int get cacheDirSize => _cacheDirSize;

  set cacheDirSize(int value) {
    assert(value != null);
    _cacheDirSize = (value != null && value >= 0) ? value : _cacheDirSize;
  }

  @Deprecated(
    'Use enableAppLifecycleBreadcrumbs instead. '
    'This option gets removed in Sentry 5.0.0',
  )
  bool get enableLifecycleBreadcrumbs => _enableAppLifecycleBreadcrumbs;

  @Deprecated(
    'Use enableAppLifecycleBreadcrumbs instead. '
    'This option gets removed in Sentry 5.0.0',
  )
  set enableLifecycleBreadcrumbs(bool value) =>
      enableAppLifecycleBreadcrumbs = value;

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
  bool get enableAppLifecycleBreadcrumbs => _enableAppLifecycleBreadcrumbs;

  set enableAppLifecycleBreadcrumbs(bool value) {
    assert(value != null);
    _enableAppLifecycleBreadcrumbs = value ?? _enableAppLifecycleBreadcrumbs;
  }

  bool _enableAppLifecycleBreadcrumbs = false;

  /// Consider disabling [enableAutoNativeBreadcrumbs] if you
  /// enable this. Otherwise you might record window metric events twice.
  /// Also consider using [enableBreadcrumbTrackingForCurrentPlatform]
  /// instead for more sensible defaults.
  bool get enableWindowMetricBreadcrumbs => _enableWindowMetricBreadcrumbs;

  set enableWindowMetricBreadcrumbs(bool value) {
    assert(value != null);
    _enableWindowMetricBreadcrumbs = value ?? _enableWindowMetricBreadcrumbs;
  }

  bool _enableWindowMetricBreadcrumbs = false;

  /// Consider disabling [enableAutoNativeBreadcrumbs] if you
  /// enable this. Otherwise you might record brightness change events twice.
  /// Also consider using [enableBreadcrumbTrackingForCurrentPlatform]
  /// instead for more sensible defaults.
  bool get enableBrightnessChangeBreadcrumbs =>
      _enableBrightnessChangeBreadcrumbs;

  set enableBrightnessChangeBreadcrumbs(bool value) {
    assert(value != null);
    _enableBrightnessChangeBreadcrumbs =
        value ?? _enableBrightnessChangeBreadcrumbs;
  }

  bool _enableBrightnessChangeBreadcrumbs = false;

  /// Consider disabling [enableAutoNativeBreadcrumbs] if you
  /// enable this. Otherwise you might record text scale change events twice.
  /// Also consider using [enableBreadcrumbTrackingForCurrentPlatform]
  /// instead for more sensible defaults.
  bool get enableTextScaleChangeBreadcrumbs =>
      _enableTextScaleChangeBreadcrumbs;

  set enableTextScaleChangeBreadcrumbs(bool value) {
    assert(value != null);
    _enableTextScaleChangeBreadcrumbs =
        value ?? _enableTextScaleChangeBreadcrumbs;
  }

  bool _enableTextScaleChangeBreadcrumbs = false;

  /// Consider disabling [enableAutoNativeBreadcrumbs] if you
  /// enable this. Otherwise you might record memory pressure events twice.
  /// Also consider using [enableBreadcrumbTrackingForCurrentPlatform]
  /// instead for more sensible defaults.
  bool get enableMemoryPressureBreadcrumbs => _enableMemoryPressureBreadcrumbs;

  set enableMemoryPressureBreadcrumbs(bool value) {
    assert(value != null);
    _enableMemoryPressureBreadcrumbs =
        value ?? _enableMemoryPressureBreadcrumbs;
  }

  bool _enableMemoryPressureBreadcrumbs = false;

  /// By default, we don't report [FlutterErrorDetails.silent] errors,
  /// but you can by enabling this flag.
  /// See https://api.flutter.dev/flutter/foundation/FlutterErrorDetails/silent.html
  bool get reportSilentFlutterErrors => _reportSilentFlutterErrors;

  set reportSilentFlutterErrors(bool value) {
    assert(value != null);
    _reportSilentFlutterErrors = value ?? _reportSilentFlutterErrors;
  }

  bool _reportSilentFlutterErrors = false;

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
    assert(platform != null);

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
        useNativeBreadcrumbTracking();
        break;
      case foundation.TargetPlatform.fuchsia:
      case foundation.TargetPlatform.linux:
      case foundation.TargetPlatform.macOS:
      case foundation.TargetPlatform.windows:
        // These platforms have no native integration, so just use the Flutter
        // integration.
        useFlutterBreadcrumbTracking();
        break;
    }
  }

  // TODO: Scope observers, enableScopeSync
}
