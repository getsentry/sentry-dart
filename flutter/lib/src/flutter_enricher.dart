import 'dart:async';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry/sentry.dart';

/// Enriches [SentryEvent]s with various kinds of information.
/// FlutterEnricher only needs to add information which aren't exposed by
/// the Dart runtime.
class FlutterEnricher implements Enricher {
  static final Enricher instance = FlutterEnricher(
      PlatformChecker(),
      DeviceInfoPlugin(),
      Enricher.defaultEnricher,
      WidgetsFlutterBinding.ensureInitialized().window);

  FlutterEnricher(
    this._checker,
    this._deviceInfoPlugin,
    this._dartEnricher,
    this._window,
  );

  final SingletonFlutterWindow _window;
  final PlatformChecker _checker;
  final DeviceInfoPlugin _deviceInfoPlugin;
  final Enricher _dartEnricher;
  WindowsDeviceInfo? _windowsDeviceInfo;
  LinuxDeviceInfo? _linuxDeviceInfo;

  @override
  FutureOr<SentryEvent> apply(SentryEvent event) async {
    if (_checker.hasNativeIntegration) {
      // For now we rely on the native integration for event enrichment
      return event;
    }
    final contexts = event.contexts.copyWith(
      device: _applyDevice(event.contexts.device),
      runtimes: _getRuntimes(event.contexts.runtimes),
    );

    contexts['Accessibility'] = <String, dynamic>{
      'accessibleNavigation':
          _window.accessibilityFeatures.accessibleNavigation,
      'boldText': _window.accessibilityFeatures.boldText,
      'disableAnimations': _window.accessibilityFeatures.disableAnimations,
      'highContrast': _window.accessibilityFeatures.highContrast,
      'invertColors': _window.accessibilityFeatures.invertColors,
      'reduceMotion': _window.accessibilityFeatures.reduceMotion,
    };

    contexts['Current Culture'] = <String, dynamic>{
      '24hourFormat': _window.alwaysUse24HourFormat,
      if (_window.locale != null) 'locale': _window.locale?.toLanguageTag(),
      if (_window.locales != null)
        'availableLocales':
            _window.locales?.map((it) => it.toLanguageTag()).toList(),
    };

    event = event.copyWith(
      contexts: contexts,
      extra: _getExtras(event.extra),
    );

    if (!_checker.isWeb && _checker.platform.isLinux) {
      event = await _applyLinux(event);
    }

    if (!_checker.isWeb && _checker.platform.isWindows) {
      event = await _applyWindows(event);
    }

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
        'locale': _window.locale.toString(),
      };
    }
    extras.putIfAbsent(
        'window_is_visible', () => _window.viewConfiguration.visible);

    extras.putIfAbsent(
        'brightness', () => describeEnum(_window.platformBrightness));

    extras.putIfAbsent('locale', () => _window.locale.toString());

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

  Future<SentryEvent> _applyWindows(SentryEvent event) async {
    // Cache device information, so that we don't need to load it every
    // time an event gets reported.
    _windowsDeviceInfo =
        _windowsDeviceInfo ?? await _deviceInfoPlugin.windowsInfo;

    // device info for windows does not expose much information

    return event;
  }

  Future<SentryEvent> _applyLinux(SentryEvent event) async {
    // Cache device information, so that we don't need to load it every
    // time an event gets reported.
    _linuxDeviceInfo = _linuxDeviceInfo ?? await _deviceInfoPlugin.linuxInfo;

    return event;
  }
}
