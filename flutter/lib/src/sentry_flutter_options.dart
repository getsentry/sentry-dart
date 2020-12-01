import 'package:flutter/foundation.dart' as foundation;

import '../sentry_flutter.dart';

// TODO: add tests

/// This class add options which are only availble in a Flutter environment.
class SentryFlutterOptions extends SentryOptions {
  /// Consider disabling [SentryOptions.enableAutoNativeBreadcrumbs] if you
  /// enable this. Otherwise you might record lifecycle events twice.
  /// Also consider using [enableBreadcrumbTrackingForCurrentPlatform()]
  /// instead for more sensible defaults.
  bool get enableLifecycleBreadcrumbs => _enableLifecycleBreadcrumbs ?? false;

  set enableLifecycleBreadcrumbs(bool value) {
    assert(value != null);
    _enableLifecycleBreadcrumbs = value;
  }

  bool _enableLifecycleBreadcrumbs = false;

  /// Consider disabling [SentryOptions.enableAutoNativeBreadcrumbs] if you
  /// enable this. Otherwise you might record window metric events twice.
  /// Also consider using [enableBreadcrumbTrackingForCurrentPlatform()]
  /// instead for more sensible defaults.
  bool get enableWindowMetricBreadcrumbs =>
      _enableWindowMetricBreadcrumbs ?? false;

  set enableWindowMetricBreadcrumbs(bool value) {
    assert(value != null);
    _enableWindowMetricBreadcrumbs = value;
  }

  bool _enableWindowMetricBreadcrumbs = false;

  /// Consider disabling [SentryOptions.enableAutoNativeBreadcrumbs] if you
  /// enable this. Otherwise you might record brightness change events twice.
  /// Also consider using [enableBreadcrumbTrackingForCurrentPlatform()]
  /// instead for more sensible defaults.
  bool get enableBrightnessChangeBreadcrumbs =>
      _enableBrightnessChangeBreadcrumbs ?? false;

  set enableBrightnessChangeBreadcrumbs(bool value) {
    assert(value != null);
    _enableBrightnessChangeBreadcrumbs = value;
  }

  bool _enableBrightnessChangeBreadcrumbs = false;

  /// Consider disabling [SentryOptions.enableAutoNativeBreadcrumbs] if you
  /// enable this. Otherwise you might record text scale change events twice.
  /// Also consider using [enableBreadcrumbTrackingForCurrentPlatform()]
  /// instead for more sensible defaults.
  bool get enableTextScaleChangeBreadcrumbs =>
      _enableTextScaleChangeBreadcrumbs ?? false;

  set enableTextScaleChangeBreadcrumbs(bool value) {
    assert(value != null);
    _enableTextScaleChangeBreadcrumbs = value;
  }

  bool _enableTextScaleChangeBreadcrumbs = false;

  /// Consider disabling [SentryOptions.enableAutoNativeBreadcrumbs] if you
  /// enable this. Otherwise you might record memory pressure events twice.
  /// Also consider using [enableBreadcrumbTrackingForCurrentPlatform()]
  /// instead for more sensible defaults.
  bool get enableMemoryPressureBreadcrumbs =>
      _enableMemoryPressureBreadcrumbs ?? false;

  set enableMemoryPressureBreadcrumbs(bool value) {
    assert(value != null);
    _enableMemoryPressureBreadcrumbs = value;
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
}
