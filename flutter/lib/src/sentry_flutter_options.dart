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

  // TODO: Scope observers, enableScopeSync
}
