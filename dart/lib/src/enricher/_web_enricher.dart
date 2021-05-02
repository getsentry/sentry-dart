import 'dart:async';
import '../protocol.dart';
import 'enricher.dart';
import 'dart:html' as html
    show window, Window, Navigator, Screen, BatteryManager;

final Enricher instance =
    WebEnricher(html.window, html.window.navigator, html.window.screen);

class WebEnricher implements Enricher {
  WebEnricher(this._window, this._navigator, this._screen);

  final html.Window _window;
  final html.Navigator _navigator;
  final html.Screen? _screen;

  @override
  FutureOr<SentryEvent> apply(SentryEvent event) async {
    final contexts = event.contexts.copyWith(
      browser: _getBrowser(event.contexts.browser),
      device: await _getDevice(event.contexts.device),
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
    );
  }

  SentryBrowser _getBrowser(SentryBrowser? browser) {
    if (browser == null) {
      return SentryBrowser(
        name: _navigator.appName,
        version: _navigator.appVersion,
      );
    } else {
      return browser.copyWith(
        name: _navigator.appName,
        version: _navigator.appVersion,
      );
    }
  }
}
