import 'package:sentry/sentry.dart';
import 'package:web/web.dart' as web show window, Window;

Window createWebWindow() {
  return WebWindow(web.window);
}

class WebWindow implements Window {
  WebWindow(this._window);

  final web.Window _window;

  @override
  WindowScreen get screen => WebScreen(_window);

  @override
  WindowNavigator get navigator => WebWindowNavigator(_window);

  @override
  WindowLocation get location => WebWindowLocation(_window);

  @override
  double get devicePixelRatio => _window.devicePixelRatio.toDouble();
}

class WebScreen implements WindowScreen {
  WebScreen(this._window);

  final web.Window _window;

  @override
  int get availableHeight => _window.screen.availHeight.toInt() ?? 0;

  @override
  int get availableWidth => _window.screen.availWidth.toInt() ?? 0;

  @override
  ScreenOrientation? get orientation =>
      _window.screen.orientation.type == "portrait"
          ? ScreenOrientation.portrait
          : _window.screen.orientation.type == "landscape"
              ? ScreenOrientation.landscape
              : null;
}

class WebWindowNavigator implements WindowNavigator {
  WebWindowNavigator(this._window);

  final web.Window _window;

  @override
  String get userAgent => _window.navigator.userAgent;

  @override
  bool? get onLine => _window.navigator.onLine;

  @override
  double? get deviceMemory => 0.0;
}

class WebWindowLocation implements WindowLocation {
  WebWindowLocation(this._window);

  final web.Window _window;

  @override
  String? get pathname => _window.location.pathname;
}
