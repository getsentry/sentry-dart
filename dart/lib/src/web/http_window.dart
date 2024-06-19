import 'dart:html' as html show window, Window;

import '../sentry_options.dart';
import 'window.dart';

Window createWindow(SentryOptions options) {
  return HttpWindow(html.window);
}

class HttpWindow implements Window {
  HttpWindow(this._window);

  final html.Window _window;

  @override
  WindowScreen get screen => HttpWindowScreen(_window);

  @override
  WindowNavigator get navigator => HttpWindowNavigator(_window);

  @override
  WindowLocation get location => HttpWindowLocation(_window);

  @override
  double get devicePixelRatio => _window.devicePixelRatio.toDouble();
}

class HttpWindowScreen implements WindowScreen {
  HttpWindowScreen(this._window);

  final html.Window _window;

  @override
  int get availableHeight => _window.screen?.available.height.toInt() ?? 0;

  @override
  int get availableWidth => _window.screen?.available.width.toInt() ?? 0;

  @override
  ScreenOrientation? get orientation =>
      _window.screen?.orientation?.type == "portrait"
          ? ScreenOrientation.portrait
          : _window.screen?.orientation?.type == "landscape"
              ? ScreenOrientation.landscape
              : null;
}

class HttpWindowNavigator implements WindowNavigator {
  HttpWindowNavigator(this._window);

  final html.Window _window;

  @override
  String get userAgent => _window.navigator.userAgent;

  @override
  bool? get onLine => _window.navigator.onLine;

  @override
  double? get deviceMemory => _window.navigator.deviceMemory?.toDouble();
}

class HttpWindowLocation implements WindowLocation {
  HttpWindowLocation(this._window);

  final html.Window _window;

  @override
  String? get pathname => _window.location.pathname;
}
