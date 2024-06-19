import '../sentry_options.dart';
import 'window.dart';

Window createWindow(SentryOptions options) {
  return NoopWindow();
}

class NoopWindow implements Window {
  @override
  WindowScreen get screen => NoopWindowScreen();

  @override
  WindowNavigator get navigator => NoopWindowNavigator();

  @override
  WindowLocation get location => NoopWindowLocation();

  @override
  double get devicePixelRatio => 1.0;
}

class NoopWindowScreen implements WindowScreen {
  NoopWindowScreen();

  @override
  int get availableHeight => 0;

  @override
  int get availableWidth => 0;

  @override
  ScreenOrientation? get orientation => null;
}

class NoopWindowNavigator implements WindowNavigator {
  NoopWindowNavigator();

  @override
  String get userAgent => "--";

  @override
  bool? get onLine => null;

  @override
  double? get deviceMemory => null;
}

class NoopWindowLocation implements WindowLocation {
  NoopWindowLocation();

  @override
  String? get pathname => null;
}
