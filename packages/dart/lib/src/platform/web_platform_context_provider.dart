import 'dart:js_interop';

import 'package:web/web.dart' as web show window, Window, Navigator;

import '../../sentry.dart';
import '../event_processor/enricher/flutter_runtime.dart';
import 'platform_context_provider.dart';

PlatformContextProvider platformContextProvider(SentryOptions options) =>
    WebPlatformContextProvider(web.window);

class WebPlatformContextProvider implements PlatformContextProvider {
  WebPlatformContextProvider(this._window);

  final web.Window _window;

  @override
  Future<Contexts> buildContexts() async {
    return Contexts(
      device: _buildDevice(),
      culture: _buildCulture(),
      runtimes: _buildRuntimes(),
    );
  }

  SentryDevice _buildDevice() {
    return SentryDevice(
      online: _window.navigator.onLine,
      memorySize: _getMemorySize(),
      orientation: _getScreenOrientation(),
      screenHeightPixels: _window.screen.availHeight,
      screenWidthPixels: _window.screen.availWidth,
      screenDensity: _window.devicePixelRatio.toDouble(),
    );
  }

  int? _getMemorySize() {
    // https://developer.mozilla.org/en-US/docs/Web/API/Navigator/deviceMemory
    final size = _window.navigator.safeDeviceMemory?.toDouble();
    final memoryByteSize = size != null ? size * 1024 * 1024 * 1024 : null;
    return memoryByteSize?.toInt();
  }

  SentryOrientation? _getScreenOrientation() {
    // https://developer.mozilla.org/en-US/docs/Web/API/ScreenOrientation
    final screenOrientation = _window.screen.orientation;
    if (screenOrientation.type.startsWith('portrait')) {
      return SentryOrientation.portrait;
    }
    if (screenOrientation.type.startsWith('landscape')) {
      return SentryOrientation.landscape;
    }
    return null;
  }

  SentryCulture _buildCulture() {
    return SentryCulture(timezone: DateTime.now().timeZoneName);
  }

  List<SentryRuntime> _buildRuntimes() {
    final flRuntime = flutterRuntime;
    final dartFlRuntime = dartFlutterRuntime;
    return [
      if (flRuntime != null) flRuntime,
      if (dartFlRuntime != null) dartFlRuntime,
    ];
  }
}

/// Some Navigator properties are not fully supported in all browsers.
/// However, package:web does not provide a safe way to access these properties,
/// and assumes they are always not null.
///
/// This extension provides a safe way to access these properties.
///
/// See: https://github.com/dart-lang/web/issues/326
///      https://github.com/fluttercommunity/plus_plugins/issues/3391
extension SafeNavigationGetterExtensions on web.Navigator {
  @JS('deviceMemory')
  external double? get safeDeviceMemory;
}
