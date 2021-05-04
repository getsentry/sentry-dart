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

    event = event.copyWith(
      contexts: event.contexts.copyWith(
        device: _applyDevice(event.contexts.device),
      ),
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
