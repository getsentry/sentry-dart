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
    final contexts = event.contexts.copyWith(
      device: _applyDevice(event.contexts.device),
      runtimes: _getRuntimes(event.contexts.runtimes),
    );

    contexts['accessibility'] = <String, dynamic>{
      'accessible_navigation':
          _window.accessibilityFeatures.accessibleNavigation,
      'bold_text': _window.accessibilityFeatures.boldText,
      'disable_animations': _window.accessibilityFeatures.disableAnimations,
      'high_contrast': _window.accessibilityFeatures.highContrast,
      'invert_colors': _window.accessibilityFeatures.invertColors,
      'reduce_motion': _window.accessibilityFeatures.reduceMotion,
    };

    final currentLifecycle = _widgetsBinding.lifecycleState;

    // conflicts with Flutter runtime if it's called Flutter
    contexts['flutter_information'] = <String, dynamic>{
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

    // The editor says it's fine without a `?` but the compiler complains
    // if it's missing
    // ignore: invalid_null_aware_operator
    final languageTag = _window.locale?.toLanguageTag();

    // The editor says it's fine without a `?` but the compiler complains
    // if it's missing
    final availableLocales =
        // ignore: invalid_null_aware_operator
        _window.locales?.map((it) => it.toLanguageTag()).toList();

    contexts['current_culture'] = <String, dynamic>{
      'is_24_hour_format': _window.alwaysUse24HourFormat,
      if (languageTag != null) 'locale': languageTag,
      if (availableLocales != null) 'available_locales': availableLocales,
      'timezone': DateTime.now().timeZoneName,
    };

    event = event.copyWith(
      contexts: contexts,
      extra: _getExtras(event.extra),
    );

    // Flutter for Web does not need a special case.
    // It's already covered by _dartEnricher.

    // And lastly apply _dartEnricher. _dartEnricher is responsible for
    // adding information which is already avaiable in Dart.
    return _dartEnricher.apply(event);
  }

  Map<String, dynamic> _getExtras(Map<String, dynamic>? extras) {
    if (extras == null) {
      return {
        'window_is_visible': _window.viewConfiguration.visible,
        // dark mode or light mode
        'brightness': describeEnum(_window.platformBrightness),
      };
    }
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

    final screenResolution =
        '${_window.physicalSize.width}x${_window.physicalSize.height}';

    if (device == null) {
      return SentryDevice(
        orientation: orientation,
        screenResolution: screenResolution,
        screenDensity: _window.devicePixelRatio,
      );
    }
    return device.copyWith(
      orientation: orientation,
      screenResolution: screenResolution,
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
