import 'package:sentry/sentry.dart';

Window createWebWindow() {
  return NoopWindow();
}

class NoopWindow implements Window {

  @override
  WindowScreen get screen => NoopScreen();

  @override
  WindowNavigator get navigator => NoopNavigator();

  @override
  WindowLocation get location => NoopLocation();

  @override
  double get devicePixelRatio => 1.0;
}

class NoopScreen implements WindowScreen {
  NoopScreen();

  @override
  int get availableHeight => 0;

  @override
  int get availableWidth => 0;

  @override
  ScreenOrientation? get orientation => null;
}

class NoopNavigator implements WindowNavigator {
  NoopNavigator();

  @override
  String get userAgent => "--";

  @override
  bool? get onLine => null;

  @override
  double? get deviceMemory => null;
}

class NoopLocation implements WindowLocation {
  NoopLocation();

  @override
  String? get pathname => null;
}
