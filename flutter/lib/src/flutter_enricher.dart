import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry/sentry.dart';

/// Enriches [SentryEvent]s with various kinds of information.
/// FlutterEnricher only needs to add information which aren't exposed by
/// the Dart runtime.
class FlutterEnricher implements Enricher {
  static final Enricher instance = FlutterEnricher(
    PlatformChecker(),
    Enricher.defaultEnricher,
    WidgetsFlutterBinding.ensureInitialized(),
  );

  FlutterEnricher(
    this._checker,
    this._dartEnricher,
    this._widgetsBinding,
  );

  final WidgetsBinding _widgetsBinding;
  final PlatformChecker _checker;
  final Enricher _dartEnricher;
  SingletonFlutterWindow get _window => _widgetsBinding.window;

  @override
  FutureOr<SentryEvent> apply(SentryEvent event) async {
    // Flutter for Web does not need a special case.
    // It's already covered by _dartEnricher.

    // First use _dartEnricher.
    // In case we have even better information available in Flutter
    // we override what's already given by _dartEnricher.
    event = await _dartEnricher.apply(event);

    final contexts = event.contexts.copyWith(
      device: _applyDevice(event.contexts.device),
      runtimes: _getRuntimes(event.contexts.runtimes),
    );

    // Flutter has a lot of Accessibility Settings available and exposes them
    contexts['accessibility'] = _getAccessibility();

    // conflicts with Flutter runtime if it's called Flutter
    contexts['flutter_information'] = _getFlutterInfo();

    contexts['culture'] = _getCulture();

    return event.copyWith(
      contexts: contexts,
      extra: _getExtras(event.extra),
    );
  }

  Map<String, dynamic> _getCulture() {
    // The editor says it's fine without a `?` but the compiler complains
    // if it's missing
    // ignore: invalid_null_aware_operator
    final languageTag = _window.locale?.toLanguageTag();

    // The editor says it's fine without a `?` but the compiler complains
    // if it's missing
    final availableLocales =
        // ignore: invalid_null_aware_operator
        _window.locales?.map((it) => it.toLanguageTag()).toList();

    return <String, dynamic>{
      'is_24_hour_format': _window.alwaysUse24HourFormat,
      if (languageTag != null) 'locale': languageTag,
      if (availableLocales != null) 'available_locales': availableLocales,
      'timezone': DateTime.now().timeZoneName,
    };
  }

  Map<String, dynamic> _getFlutterInfo() {
    final currentLifecycle = _widgetsBinding.lifecycleState;

    return <String, dynamic>{
      if (debugBrightnessOverride != null)
        'debug_brightness_override': debugBrightnessOverride,
      if (debugDefaultTargetPlatformOverride != null)
        'debug_default_target_platform_override':
            debugDefaultTargetPlatformOverride,
      'initial_lifecycle_state': _window.initialLifecycleState,
      'default_route_name': _window.defaultRouteName,
      if (currentLifecycle != null)
        'current_lifecycle_state': describeEnum(currentLifecycle),
    };
  }

  Map<String, dynamic> _getAccessibility() {
    return <String, dynamic>{
      'accessible_navigation':
          _window.accessibilityFeatures.accessibleNavigation,
      'bold_text': _window.accessibilityFeatures.boldText,
      'disable_animations': _window.accessibilityFeatures.disableAnimations,
      'high_contrast': _window.accessibilityFeatures.highContrast,
      'invert_colors': _window.accessibilityFeatures.invertColors,
      'reduce_motion': _window.accessibilityFeatures.reduceMotion,
    };
  }

  Map<String, dynamic> _getExtras(Map<String, dynamic>? extras) {
    extras = extras ?? {};
    extras.putIfAbsent(
        'window_is_visible', () => _window.viewConfiguration.visible);

    extras.putIfAbsent(
        'brightness', () => describeEnum(_window.platformBrightness));
    return extras;
  }

  SentryDevice _applyDevice(SentryDevice? device) {
    final orientation = _window.physicalSize.width > _window.physicalSize.height
        ? SentryOrientation.landscape
        : SentryOrientation.portrait;

    return (device ?? SentryDevice()).copyWith(
      orientation: orientation,
      screenHeightPixels: _window.physicalSize.height.toInt(),
      screenWidthPixels: _window.physicalSize.width.toInt(),
      screenDensity: _window.devicePixelRatio,
    );
  }

  List<SentryRuntime> _getRuntimes(List<SentryRuntime>? runtimes) {
    var flutterRuntimeDescription = '';

    // See
    // - https://flutter.dev/docs/testing/build-modes
    // - https://github.com/flutter/flutter/wiki/Flutter%27s-modes
    // TODO profile mode
    if (_checker.isWeb) {
      if (_checker.isDebugMode()) {
        flutterRuntimeDescription = 'Flutter on Web with dartdevc';
      } else if (_checker.isReleaseMode()) {
        flutterRuntimeDescription = 'Flutter on Web with dart2js';
      }
    } else {
      if (_checker.isDebugMode()) {
        flutterRuntimeDescription = 'Flutter on Dart VM';
      } else if (_checker.isReleaseMode()) {
        flutterRuntimeDescription = 'Flutter on Dart AOT';
      }
    }

    final flutterRuntime = SentryRuntime(
      name: 'Flutter',
      rawDescription: flutterRuntimeDescription,
    );

    if (runtimes == null) {
      return [flutterRuntime];
    }
    return [...runtimes, flutterRuntime];
  }
}
