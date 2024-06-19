abstract class Window {
  WindowScreen get screen;
  WindowNavigator get navigator;
  WindowLocation get location;

  double get devicePixelRatio;
}

abstract class WindowScreen {
  WindowScreen();

  int get availableHeight;
  int get availableWidth;

  ScreenOrientation? get orientation;
}

abstract class WindowNavigator {
  WindowNavigator();

  String get userAgent;

  bool? get onLine;

  double? get deviceMemory;
}

abstract class WindowLocation {
  String? get pathname;
}

enum ScreenOrientation {
  portrait,
  landscape,
}
