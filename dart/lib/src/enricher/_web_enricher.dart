import 'dart:async';

import '../platform/_web_platform.dart';
import '../platform/platform.dart';
import '../protocol.dart';
import 'enricher.dart';
import 'dart:html' as html
    show window, Window, Navigator, Screen, BatteryManager;

final Enricher instance = WebEnricher(
  html.window,
  html.window.navigator,
  html.window.screen,
  WebPlatform(),
);

class WebEnricher implements Enricher {
  WebEnricher(
    this._window,
    this._navigator,
    this._screen,
    this._platform,
  );

  final html.Window _window;
  final html.Navigator _navigator;
  final html.Screen? _screen;
  final Platform _platform;

  @override
  FutureOr<SentryEvent> apply(SentryEvent event) async {
    final contexts = event.contexts.copyWith(
      browser: _getBrowser(event.contexts.browser),
      device: await _getDevice(event.contexts.device),
      operatingSystem: _getOperatingSystem(event.contexts.operatingSystem),
      runtimes: _getRuntimes(event.contexts.runtimes),
    );

    return event.copyWith(
      contexts: contexts,
    );
  }

  Future<SentryDevice> _getDevice(SentryDevice? device) async {
    final batteryManager =
        await _navigator.getBattery() as html.BatteryManager?;
    var level = batteryManager?.level;
    if (level != null) {
      // batteryManager?.level is a value between 0 and 1
      level = level * 100;
    }
    final charging = batteryManager?.charging;

    // https://developer.mozilla.org/en-US/docs/Web/API/Navigator/deviceMemory
    final size = _navigator.deviceMemory?.toDouble();
    final memoryByteSize = size != null ? size * 1024 * 1024 * 1024 : null;

    // https://developer.mozilla.org/en-US/docs/Web/API/ScreenOrientation
    SentryOrientation? orientation;
    final screenOrientation = _screen?.orientation;
    if (screenOrientation != null) {
      if (screenOrientation.type?.startsWith('portrait') ?? false) {
        orientation = SentryOrientation.portrait;
      }
      if (screenOrientation.type?.startsWith('landscape') ?? false) {
        orientation = SentryOrientation.landscape;
      }
    }

    String? screenResolution;
    var screen = _screen;
    if (screen != null) {
      screenResolution = '${screen.width}x${screen.height}';
    }

    /* TODO storage
    final storage = await _navigator.storage?.estimate();
    final availableStorage = storage?['quota'];
    final usedStorage = storage?['usage'];
    */

    if (device == null) {
      return SentryDevice(
        batteryLevel: level?.toDouble(),
        charging: charging,
        online: _navigator.onLine,
        memorySize: memoryByteSize?.toInt(),
        orientation: orientation,
        screenResolution: screenResolution,
        screenDensity: _window.devicePixelRatio.toDouble(),
      );
    }
    return device.copyWith(
      batteryLevel: level?.toDouble(),
      charging: charging,
      online: _navigator.onLine,
      memorySize: memoryByteSize?.toInt(),
      orientation: orientation,
      screenResolution: screenResolution,
      screenDensity: _window.devicePixelRatio.toDouble(),
    );
  }

  SentryBrowser _getBrowser(SentryBrowser? browser) {
    // TODO: Figure out how to send the correct name and version
    if (browser == null) {
      return SentryBrowser(
        name: _navigator.appName,
        version: _navigator.userAgent,
      );
    } else {
      return browser.copyWith(
        name: _navigator.appName,
        version: _navigator.appVersion,
      );
    }
  }

  SentryOperatingSystem _getOperatingSystem(SentryOperatingSystem? os) {
    if (os == null) {
      return SentryOperatingSystem(
        name: _platform.operatingSystem,
      );
    } else {
      return os.copyWith(
        name: _platform.operatingSystem,
      );
    }
  }

  List<SentryRuntime> _getRuntimes(List<SentryRuntime>? runtimes) {
    final dartRuntime = SentryRuntime(name: 'Dart', rawDescription: 'dart2js');

    final browserRuntime = SentryRuntime(name: 'Browser');
    if (runtimes == null) {
      return [
        dartRuntime,
        browserRuntime,
      ];
    }
    return [
      ...runtimes,
      dartRuntime,
      browserRuntime,
    ];
  }
}
