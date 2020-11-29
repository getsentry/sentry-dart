import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// This is a `WidgetsBindingObserver` which can observe some events of a
/// Flutter application.
/// These are for example events related to its lifecycle, accessibility
/// features, display features and more.
///
/// This class calls `WidgetsBinding.instance` but we don't need to call
/// `WidgetsFlutterBinding.ensureInitialized()` because we can only add this
/// class to an instance of `WidgetsBinding`.
///
/// See also:
///   - [WidgetsBindingObserver](https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html)
class SentryWidgetsBindingObserver with WidgetsBindingObserver {
  SentryWidgetsBindingObserver({Hub hub}) {
    this.hub = hub ?? HubAdapter();
  }

  Hub hub;

  /// This method records lifecycle events.
  /// It tries to mimic the behavior of ActivityBreadcrumbsIntegration of Sentry
  /// Android for lifecycle events.
  ///
  /// On Android and iOS this records lifecycle event breadcrumbs which loosely
  /// correspond to their respectiv platforms lifecycle events.
  ///
  /// Does this need to be tracked? The nativ Android an iOS integration
  /// also tracks this but what about Web, Linux, Windows and MacOS?
  /// The message could include that this is a Flutter message.
  ///
  /// See also:
  ///   - [WidgetsBindingObserver](https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // According to
    // https://develop.sentry.dev/sdk/event-payloads/breadcrumbs/
    // this is of the type navigation.
    hub.addBreadcrumb(Breadcrumb(
      message: _lifecycleToString(state),
      category: 'ui.lifecycle',
      type: 'navigation',
    ));
  }

  /// Called when the application's dimensions change. For example,
  /// when a phone is rotated or an application window is resized.
  ///
  /// See also:
  ///   - [Window.onMetricsChanged](https://api.flutter.dev/flutter/dart-ui/Window/onMetricsChanged.html)
  @override
  void didChangeMetrics() {
    // Should this method push a new scope with a new Device Context?
    final window = WidgetsBinding.instance.window;
    hub.addBreadcrumb(Breadcrumb(
      message: 'Screen sized changed',
      category: 'ui.lifecycle',
      data: <String, dynamic>{
        'new_pixel_ratio': window.devicePixelRatio,
        'new_height': window.physicalSize.height,
        'new_width': window.physicalSize.width,
      },
    ));
  }

  /// See also:
  ///   - [Window.onPlatformBrightnessChanged](https://api.flutter.dev/flutter/dart-ui/Window/onPlatformBrightnessChanged.html)
  @override
  void didChangePlatformBrightness() {
    final brightness = WidgetsBinding.instance.window.platformBrightness;
    final brightnessDescription =
        brightness == Brightness.dark ? 'dark' : 'light';

    hub.addBreadcrumb(Breadcrumb(
      message: 'Platform brightness was changed to $brightnessDescription.',
      category: 'ui.lifecycle',
    ));
  }

  /// See also:
  ///   - [Window.onTextScaleFactorChanged]https://api.flutter.dev/flutter/dart-ui/Window/onTextScaleFactorChanged.html)
  @override
  void didChangeTextScaleFactor() {
    final newTextScaleFactor = WidgetsBinding.instance.window.textScaleFactor;
    hub.addBreadcrumb(Breadcrumb(
      message: 'Text scale factor changed to $newTextScaleFactor.',
      category: 'ui',
      level: SentryLevel.warning,
    ));
  }

  /// A call to this method indicates that the operating system would like
  /// applications to release caches to free up more memory.
  @override
  void didHaveMemoryPressure() {
    const message =
        'App had memory pressure. This indicates that the operating system '
        'would like applications to release caches to free up more memory.';
    hub.addBreadcrumb(Breadcrumb(
      message: message,
      // This is kinda bad. Therefore this gets added as a warning.
      level: SentryLevel.warning,
    ));
  }

  static String _lifecycleToString(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        return 'resumed';
      case AppLifecycleState.inactive:
        return 'inactive';
      case AppLifecycleState.paused:
        return 'paused';
      case AppLifecycleState.detached:
        return 'detached';
    }
    return '';
  }

  /* 
  These are also methods of `WidgetsBindingObserver` but are currently not
  implemented because I'm not sure what to do with them. See the reasoning 
  for each method. If these methods are implemented the class definition should
  be changed from `class SentryWidgetsBindingObserver with WidgetsBindingObserver`
  to `class SentryWidgetsBindingObserver implements WidgetsBindingObserver`.

  // Figure out which accessibility features changed
  @override
  void didChangeAccessibilityFeatures() {}

  // Figure out which locales changed
  @override
  void didChangeLocales(List<Locale> locale) {}
  
  // Does this need to be considered?
  // On the one side this is already included in the SentryNavigationObserver
  // but on the other side, SentryNavigationObserver must be manually added by 
  // the user.
  @override
  Future<bool> didPopRoute() => Future<bool>.value(false);
  
  // See explanation of didPopRoute
  @override
  Future<bool> didPushRoute(String route) => Future<bool>.value(false);
  
  // See explanation of didPopRoute
  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    return didPushRoute(routeInformation.location);
  }
  */
}
