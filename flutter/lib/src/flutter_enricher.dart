import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:sentry/sentry.dart';

/// Enriches [SentryEvent]s with various kinds of information.
class FlutterEnricher implements Enricher {
  static final Enricher instance = FlutterEnricher(
      PlatformChecker(), DeviceInfoPlugin(), Enricher.defaultEnricher);

  FlutterEnricher(
    this._checker,
    this._deviceInfoPlugin,
    this._dartEnricher,
  );

  final PlatformChecker _checker;
  final DeviceInfoPlugin _deviceInfoPlugin;
  final Enricher _dartEnricher;

  @override
  FutureOr<SentryEvent> apply(SentryEvent event) async {
    if (_checker.hasNativeIntegration) {
      // for now we rely on the native integration for this
      return event;
    }

    return _dartEnricher.apply(event);
  }

  WindowsDeviceInfo? _windowsDeviceInfo;

  Future<SentryEvent> _applyWindows(SentryEvent event) async {
    // Cache device information, so that we don't need to load it every
    // time an event gets reported.
    _windowsDeviceInfo =
        _windowsDeviceInfo ?? await _deviceInfoPlugin.windowsInfo;

    return event;
  }

  Future<SentryEvent> _applyLinux(SentryEvent event) async {
    return event;
  }
}
