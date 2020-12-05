import 'package:flutter/foundation.dart' as foundation;
import 'package:sentry/sentry.dart';

/// This class add options which are only availble in a Flutter environment.
class SentryFlutterOptions extends SentryOptions {
  SentryFlutterOptions() : super();

  bool _enableAutoSessionTracking = true;

  /// Enable or disable the Auto session tracking on the Native SDKs (Android/iOS)
  bool get enableAutoSessionTracking => _enableAutoSessionTracking;

  set enableAutoSessionTracking(bool enableAutoSessionTracking) {
    _enableAutoSessionTracking =
        enableAutoSessionTracking ?? _enableAutoSessionTracking;
  }

  bool _enableNativeCrashHandling = true;

  /// Enable or Disable the Crash handling on the Native SDKs (Android/iOS)
  bool get enableNativeCrashHandling => _enableNativeCrashHandling;

  set enableNativeCrashHandling(bool nativeCrashHandling) {
    _enableNativeCrashHandling =
        nativeCrashHandling ?? _enableNativeCrashHandling;
  }

  int _autoSessionTrackingIntervalMillis = 30000;

  /// The session tracking interval in millis. This is the interval to end a session if the App goes
  /// to the background.
  /// See: enableAutoSessionTracking
  int get autoSessionTrackingIntervalMillis =>
      _autoSessionTrackingIntervalMillis;

  set autoSessionTrackingIntervalMillis(int autoSessionTrackingIntervalMillis) {
    _autoSessionTrackingIntervalMillis =
        (autoSessionTrackingIntervalMillis != null &&
                autoSessionTrackingIntervalMillis >= 0)
            ? autoSessionTrackingIntervalMillis
            : _autoSessionTrackingIntervalMillis;
  }

  bool _anrEnabled = false;

  /// Enable or disable ANR (Application Not Responding) Default is enabled Used by AnrIntegration.
  /// Available only for Android.
  /// Disabled by default as the stack trace most of the time is hanging on
  /// the MessageChannel from Flutter, but you can enable it if you have
  /// Java/Kotlin code as well.
  bool get anrEnabled => _anrEnabled;

  set anrEnabled(bool anrEnabled) {
    _anrEnabled = anrEnabled ?? _anrEnabled;
  }

  int _anrTimeoutIntervalMillis = 5000;

  /// ANR Timeout internal in Millis Default is 5000 = 5s Used by AnrIntegration.
  /// Available only for Android.
  /// See: anrEnabled
  int get anrTimeoutIntervalMillis => _anrTimeoutIntervalMillis;

  set anrTimeoutIntervalMillis(int anrTimeoutIntervalMillis) {
    _anrTimeoutIntervalMillis =
        (anrTimeoutIntervalMillis != null && anrTimeoutIntervalMillis >= 0)
            ? anrTimeoutIntervalMillis
            : _anrTimeoutIntervalMillis;
  }

  bool _enableAutoNativeBreadcrumbs = true;

  /// Enable or disable the Automatic breadcrumbs on the Native platforms (Android/iOS)
  /// Screen's lifecycle, App's lifecycle, System events, etc...
  bool get enableAutoNativeBreadcrumbs => _enableAutoNativeBreadcrumbs;

  set enableAutoNativeBreadcrumbs(bool enableAutoNativeBreadcrumbs) {
    _enableAutoNativeBreadcrumbs =
        enableAutoNativeBreadcrumbs ?? _enableAutoNativeBreadcrumbs;
  }

  int _cacheDirSize = 30;

  /// The cache dir. size for capping the number of events Default is 30.
  /// Only available for Android.
  int get cacheDirSize => _cacheDirSize;

  set cacheDirSize(int cacheDirSize) {
    _cacheDirSize = (cacheDirSize != null && cacheDirSize >= 0)
        ? cacheDirSize
        : _cacheDirSize;
  }

  /// Consider disabling [SentryOptions.enableAutoNativeBreadcrumbs] if you
  /// enable this. Otherwise you might record lifecycle events twice.
  /// Also consider using [enableBreadcrumbTrackingForCurrentPlatform()]
  /// instead for more sensible defaults.
  bool get enableLifecycleBreadcrumbs => _enableLifecycleBreadcrumbs;

  set enableLifecycleBreadcrumbs(bool value) {
    assert(value != null);
    _enableLifecycleBreadcrumbs = value ?? _enableLifecycleBreadcrumbs;
  }

  bool _enableLifecycleBreadcrumbs = false;

  /// Consider disabling [SentryOptions.enableAutoNativeBreadcrumbs] if you
  /// enable this. Otherwise you might record window metric events twice.
  /// Also consider using [enableBreadcrumbTrackingForCurrentPlatform()]
  /// instead for more sensible defaults.
  bool get enableWindowMetricBreadcrumbs => _enableWindowMetricBreadcrumbs;

  set enableWindowMetricBreadcrumbs(bool value) {
    assert(value != null);
    _enableWindowMetricBreadcrumbs = value ?? _enableWindowMetricBreadcrumbs;
  }

  bool _enableWindowMetricBreadcrumbs = false;

  /// Consider disabling [SentryOptions.enableAutoNativeBreadcrumbs] if you
  /// enable this. Otherwise you might record brightness change events twice.
  /// Also consider using [enableBreadcrumbTrackingForCurrentPlatform()]
  /// instead for more sensible defaults.
  bool get enableBrightnessChangeBreadcrumbs =>
      _enableBrightnessChangeBreadcrumbs;

  set enableBrightnessChangeBreadcrumbs(bool value) {
    assert(value != null);
    _enableBrightnessChangeBreadcrumbs =
        value ?? _enableBrightnessChangeBreadcrumbs;
  }

  bool _enableBrightnessChangeBreadcrumbs = false;

  /// Consider disabling [SentryOptions.enableAutoNativeBreadcrumbs] if you
  /// enable this. Otherwise you might record text scale change events twice.
  /// Also consider using [enableBreadcrumbTrackingForCurrentPlatform()]
  /// instead for more sensible defaults.
  bool get enableTextScaleChangeBreadcrumbs =>
      _enableTextScaleChangeBreadcrumbs;

  set enableTextScaleChangeBreadcrumbs(bool value) {
    assert(value != null);
    _enableTextScaleChangeBreadcrumbs =
        value ?? _enableTextScaleChangeBreadcrumbs;
  }

  bool _enableTextScaleChangeBreadcrumbs = false;

  /// Consider disabling [SentryOptions.enableAutoNativeBreadcrumbs] if you
  /// enable this. Otherwise you might record memory pressure events twice.
  /// Also consider using [enableBreadcrumbTrackingForCurrentPlatform()]
  /// instead for more sensible defaults.
  bool get enableMemoryPressureBreadcrumbs => _enableMemoryPressureBreadcrumbs;

  set enableMemoryPressureBreadcrumbs(bool value) {
    assert(value != null);
    _enableMemoryPressureBreadcrumbs =
        value ?? _enableMemoryPressureBreadcrumbs;
  }

  bool _enableMemoryPressureBreadcrumbs = false;

  /// By using this, you are disabling native [Breadcrumb] tracking and instead
  /// you are just tracking [Breadcrumb]s which result from events available
  /// in the current Flutter environment.
  void useFlutterBreadcrumbTracking() {
    enableLifecycleBreadcrumbs = true;
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
    enableLifecycleBreadcrumbs = false;
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

  /// You should probably use [enableBreadcrumbTrackingForCurrentPlatform()].
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
