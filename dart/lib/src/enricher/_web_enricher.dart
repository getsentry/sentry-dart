import 'dart:async';

import '../platform_checker.dart';

import '../protocol.dart';
import 'enricher.dart';
import 'dart:html' as html
    show window, Window, Navigator, Screen, BatteryManager;

final Enricher instance = WebEnricher(
  html.window,
  html.window.navigator,
  html.window.screen,
  PlatformChecker(),
);

class WebEnricher implements Enricher {
  WebEnricher(
    this._window,
    this._navigator,
    this._screen,
    this._platformChecker,
  );

  final html.Window _window;
  final html.Navigator _navigator;
  final html.Screen? _screen;
  final PlatformChecker _platformChecker;

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

    int? screenHeight;
    int? screenWidth;

    // This is the size of the physical screen.
    // The size of the browser window might differ.
    var screen = _screen;
    if (screen != null) {
      screenWidth = screen.width;
      screenHeight = screen.height;
    }

    /* TODO storage
    final storage = await _navigator.storage?.estimate();
    final availableStorage = storage?['quota'];
    final usedStorage = storage?['usage'];
    */

    return (device ?? SentryDevice()).copyWith(
      batteryLevel: level?.toDouble(),
      charging: charging,
      online: _navigator.onLine,
      memorySize: memoryByteSize?.toInt(),
      orientation: orientation,
      screenHeightPixels: screenHeight,
      screenWidthPixels: screenWidth,
      screenDensity: _window.devicePixelRatio.toDouble(),
      timezone: DateTime.now().timeZoneName,
    );
  }

  SentryBrowser _getBrowser(SentryBrowser? browser) {
    // TODO: Figure out how to send the correct name and version
    return (browser ?? SentryBrowser()).copyWith(
      name: _navigator.appName,
      version: _navigator.appVersion,
    );
  }

  SentryOperatingSystem _getOperatingSystem(SentryOperatingSystem? os) {
    return (os ?? SentryOperatingSystem()).copyWith(
      name: _platformChecker.platform.operatingSystem,
    );
  }

  List<SentryRuntime> _getRuntimes(List<SentryRuntime>? runtimes) {
    var dartRuntimeDescription = '';
    if (_platformChecker.isDebugMode()) {
      dartRuntimeDescription = 'Dart with dartdevc';
    } else if (_platformChecker.isReleaseMode()) {
      dartRuntimeDescription = 'Dart with dart2js';
    }

    final dartRuntime = SentryRuntime(
      name: 'Dart',
      rawDescription: dartRuntimeDescription,
    );

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
