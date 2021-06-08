import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry/sentry.dart';

typedef WidgetBindingGetter = WidgetsBinding? Function();

/// Enriches [SentryEvent]s with various kinds of information.
/// FlutterEnricher only needs to add information which aren't exposed by
/// the Dart runtime.
class FlutterEnricherEventProcessor {
  FlutterEnricherEventProcessor(
    this._checker,
    this._getWidgetsBinding,
    this.hasNativeIntegration,
  );

  factory FlutterEnricherEventProcessor.simple({
    required PlatformChecker checker,
    required bool hasNativeIntegration,
  }) {
    return FlutterEnricherEventProcessor(
      checker,
      () => WidgetsBinding.instance,
      hasNativeIntegration,
    );
  }

  final bool hasNativeIntegration;

  // We can't use `WidgetsBinding` as a direct parameter
  // because it must be called inside the `runZoneGuarded`-Integration.
  // Thus we call it on demand after all the initialization happend.
  final WidgetBindingGetter _getWidgetsBinding;
  WidgetsBinding? get _widgetsBinding => _getWidgetsBinding();
  final PlatformChecker _checker;
  SingletonFlutterWindow? get _window => _widgetsBinding?.window;
  Map<String, String> _packages = {};

  FutureOr<SentryEvent> apply(
    SentryEvent event, {
    dynamic hint,
  }) async {
    // If there's a native integration available, it probably has better
    // information available than Flutter.
    final device =
        hasNativeIntegration ? null : _getDevice(event.contexts.device);

    final contexts = event.contexts.copyWith(
      device: device,
      runtimes: _getRuntimes(event.contexts.runtimes),
      culture: _getCulture(event.contexts.culture),
    );

    // Flutter has a lot of Accessibility Settings available and exposes them
    contexts['accessibility'] = _getAccessibilityContext();

    // Conflicts with Flutter runtime if it's just called `Flutter`
    contexts['flutter_context'] = _getFlutterContext();

    return event.copyWith(
      contexts: contexts,
      modules: await _getPackages(),
    );
  }

  /// Packages are loaded from [LicenseRegistry].
  /// This is currently the only way to know which packages are used.
  /// This however has some drawbacks:
  /// - Only packages with licenses are known
  /// - No version information is available
  /// - Flutter's native dependencies are also included.
  FutureOr<Map<String, String>> _getPackages() async {
    if (_packages.isEmpty) {
      // This can take some time.
      // Therefore we cache this after running
      var packages = <String>{};
      // The license registry has a list of licenses entries (MIT, Apache...).
      // Each license entry has a list of packages which licensed under this particular license.
      // Libraries can be dual licensed.
      //
      // We don't care about those license issues, we just want each package name once.
      // Therefore we add each name to a set to make sure we only add it once.
      await LicenseRegistry.licenses.forEach(
        (entry) => packages.addAll(
          entry.packages.toList(),
        ),
      );

      _packages = Map.fromEntries(
        packages.map(
          (e) => MapEntry(e, 'unknown'),
        ),
      );
    }
    return _packages;
  }

  SentryCulture _getCulture(SentryCulture? culture) {
    // The editor says it's fine without a `?` but the compiler complains
    // if it's missing
    // ignore: invalid_null_aware_operator
    final languageTag = _window?.locale?.toLanguageTag();

    // Future enhancement:
    // _window?.locales

    return (culture ?? SentryCulture()).copyWith(
      is24HourFormat: culture?.is24HourFormat ?? _window?.alwaysUse24HourFormat,
      locale: culture?.locale ?? languageTag,
      timezone: culture?.timezone ?? DateTime.now().timeZoneName,
    );
  }

  Map<String, dynamic> _getFlutterContext() {
    final currentLifecycle = _widgetsBinding?.lifecycleState;

    return <String, dynamic>{
      if (debugBrightnessOverride != null)
        'debug_brightness_override': debugBrightnessOverride,
      if (debugDefaultTargetPlatformOverride != null)
        'debug_default_target_platform_override':
            debugDefaultTargetPlatformOverride,
      if (_window?.initialLifecycleState.isNotEmpty ?? false)
        'initial_lifecycle_state': _window?.initialLifecycleState,
      if (_window?.defaultRouteName.isNotEmpty ?? false)
        'default_route_name': _window?.defaultRouteName,
      if (currentLifecycle != null)
        'current_lifecycle_state': describeEnum(currentLifecycle),
      // Seems to always return false.
      // Also always fails in tests.
      // See https://github.com/flutter/flutter/issues/83919
      // 'window_is_visible': _window.viewConfiguration.visible,
    };
  }

  Map<String, dynamic> _getAccessibilityContext() {
    final window = _window;
    if (window == null) {
      return {};
    }
    return <String, dynamic>{
      'accessible_navigation':
          window.accessibilityFeatures.accessibleNavigation,
      'bold_text': window.accessibilityFeatures.boldText,
      'disable_animations': window.accessibilityFeatures.disableAnimations,
      'high_contrast': window.accessibilityFeatures.highContrast,
      'invert_colors': window.accessibilityFeatures.invertColors,
      'reduce_motion': window.accessibilityFeatures.reduceMotion,
    };
  }

  SentryDevice? _getDevice(SentryDevice? device) {
    final window = _window;
    if (window == null) {
      return device;
    }
    final orientation = window.physicalSize.width > window.physicalSize.height
        ? SentryOrientation.landscape
        : SentryOrientation.portrait;

    return (device ?? SentryDevice()).copyWith(
      orientation: device?.orientation ?? orientation,
      screenHeightPixels:
          device?.screenHeightPixels ?? window.physicalSize.height.toInt(),
      screenWidthPixels:
          device?.screenWidthPixels ?? window.physicalSize.width.toInt(),
      screenDensity: device?.screenDensity ?? window.devicePixelRatio,
      theme: device?.theme ?? describeEnum(window.platformBrightness),
    );
  }

  List<SentryRuntime> _getRuntimes(List<SentryRuntime>? runtimes) {
    var compiler = '';

    // See
    // - https://flutter.dev/docs/testing/build-modes
    // - https://github.com/flutter/flutter/wiki/Flutter%27s-modes
    if (_checker.isWeb) {
      if (_checker.isDebugMode()) {
        compiler = 'dartdevc';
      } else if (_checker.isReleaseMode() || _checker.isProfileMode()) {
        compiler = 'dart2js';
      }
    } else {
      if (_checker.isDebugMode()) {
        compiler = 'Dart VM';
      } else if (_checker.isReleaseMode() || _checker.isProfileMode()) {
        compiler = 'Dart AOT';
      }
    }

    final flutterRuntime = SentryRuntime(
      key: 'sentry_flutter_runtime',
      name: 'Flutter',
      compiler: compiler,
    );

    if (runtimes == null || runtimes.isEmpty) {
      return [flutterRuntime];
    }

    return [
      ...runtimes,
      flutterRuntime,
    ];
  }
}
