import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../sentry_flutter.dart';
import 'utils/debouncer.dart';

/// This is a `WidgetsBindingObserver` which can observe some events of a
/// Flutter application.
/// These are for example events related to its lifecycle, accessibility
/// features, display features and more.
///
/// The tracking of each event can be configured via [SentryFlutterOptions]
///
/// This class calls `WidgetsBinding.instance` but we don't need to call
/// `WidgetsFlutterBinding.ensureInitialized()` because we can only add this
/// class to an instance of `WidgetsBinding`.
///
/// See also:
///   - [WidgetsBindingObserver](https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html)
class SentryWidgetsBindingObserver with WidgetsBindingObserver {
  SentryWidgetsBindingObserver({
    Hub? hub,
    required SentryFlutterOptions options,
  })  : _hub = hub ?? HubAdapter(),
        _options = options,
        _screenSizeStreamController = StreamController(sync: true) {
    if (_options.enableWindowMetricBreadcrumbs) {
      _screenSizeStreamController.stream
          .map(
            (window) => {
              'new_pixel_ratio': window?.devicePixelRatio,
              'new_height': window?.physicalSize.height,
              'new_width': window?.physicalSize.width,
            },
          )
          .distinct(mapEquals)
          .skip(1) // Skip initial event added below in constructor
          .listen(_onScreenSizeChanged);

      // ignore: deprecated_member_use
      final window = _options.bindingUtils.instance?.window;
      _screenSizeStreamController.add(window);
    }
  }

  final Hub _hub;
  final SentryFlutterOptions _options;

  // ignore: deprecated_member_use
  final StreamController<SingletonFlutterWindow?> _screenSizeStreamController;

  final _didChangeMetricsDebouncer = Debouncer(milliseconds: 100);

  /// This method records lifecycle events.
  /// It tries to mimic the behavior of ActivityBreadcrumbsIntegration of Sentry
  /// Android for lifecycle events.
  ///
  /// On Android and iOS this records lifecycle event breadcrumbs which loosely
  /// correspond to their respectiv platforms lifecycle events.
  ///
  /// See also:
  ///   - [WidgetsBindingObserver](https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_options.enableAppLifecycleBreadcrumbs) {
      return;
    }
    // References:
    // https://develop.sentry.dev/sdk/event-payloads/breadcrumbs/
    // https://github.com/getsentry/sentry-java/blob/de00462e3499fa9a21a7992317503f1ccda7d226/sentry-android-core/src/main/java/io/sentry/android/core/LifecycleWatcher.java#L119-L128
    _hub.addBreadcrumb(Breadcrumb(
      category: 'app.lifecycle',
      type: 'navigation',
      data: <String, String>{
        'state': state.name,
      },
      // ignore: invalid_use_of_internal_member
      timestamp: _options.clock(),
    ));
  }

  /// Called when the application's dimensions change. For example,
  /// when a phone is rotated or an application window is resized.
  ///
  /// See also:
  ///   - [SingletonFlutterWindow.onMetricsChanged](https://api.flutter.dev/flutter/dart-ui/SingletonFlutterWindow/onMetricsChanged.html)
  @override
  void didChangeMetrics() {
    if (!_options.enableWindowMetricBreadcrumbs) {
      return;
    }

    _didChangeMetricsDebouncer.run(() {
      // ignore: deprecated_member_use
      final window = _options.bindingUtils.instance?.window;
      _screenSizeStreamController.add(window);
    });
  }

  void _onScreenSizeChanged(Map<String, dynamic> data) {
    _hub.addBreadcrumb(Breadcrumb(
      message: 'Screen size changed',
      category: 'device.screen',
      type: 'navigation',
      data: data,
      // ignore: invalid_use_of_internal_member
      timestamp: _options.clock(),
    ));
  }

  /// See also:
  ///   - [Window.onPlatformBrightnessChanged](https://api.flutter.dev/flutter/dart-ui/Window/onPlatformBrightnessChanged.html)
  @override
  void didChangePlatformBrightness() {
    if (!_options.enableBrightnessChangeBreadcrumbs) {
      return;
    }
    final brightness =
        // ignore: deprecated_member_use
        _options.bindingUtils.instance?.window.platformBrightness;
    final brightnessDescription =
        brightness == Brightness.dark ? 'dark' : 'light';

    _hub.addBreadcrumb(Breadcrumb(
      message: 'Platform brightness was changed to $brightnessDescription.',
      type: 'system',
      category: 'device.event',
      data: <String, String>{
        'action': 'BRIGHTNESS_CHANGED_TO_${brightnessDescription.toUpperCase()}'
      },
      // ignore: invalid_use_of_internal_member
      timestamp: _options.clock(),
    ));
  }

  /// See also:
  ///   - [Window.onTextScaleFactorChanged]https://api.flutter.dev/flutter/dart-ui/Window/onTextScaleFactorChanged.html)
  @override
  void didChangeTextScaleFactor() {
    if (!_options.enableTextScaleChangeBreadcrumbs) {
      return;
    }
    final newTextScaleFactor =
        // ignore: deprecated_member_use
        _options.bindingUtils.instance?.window.textScaleFactor;

    _hub.addBreadcrumb(Breadcrumb(
      message: 'Text scale factor changed to $newTextScaleFactor.',
      type: 'system',
      category: 'device.event',
      data: <String, String>{
        'action': 'TEXT_SCALE_CHANGED_TO_$newTextScaleFactor'
      },
      // ignore: invalid_use_of_internal_member
      timestamp: _options.clock(),
    ));
  }

  /// A call to this method indicates that the operating system would like
  /// applications to release caches to free up more memory.
  @override
  void didHaveMemoryPressure() {
    if (!_options.enableMemoryPressureBreadcrumbs) {
      return;
    }
    // See
    // - https://develop.sentry.dev/sdk/event-payloads/breadcrumbs/
    // - https://github.com/getsentry/sentry-java/blob/main/sentry-android-core/src/main/java/io/sentry/android/core/AppComponentsBreadcrumbsIntegration.java#L98-L135
    // on why this breadcrumb looks like this.
    const message =
        'App had memory pressure. This indicates that the operating system '
        'would like applications to release caches to free up more memory.';
    _hub.addBreadcrumb(Breadcrumb(
      message: message,
      type: 'system',
      category: 'device.event',
      data: <String, String>{
        'action': 'LOW_MEMORY',
      },
      // This is kinda bad. Therefore this gets added as a warning.
      level: SentryLevel.warning,
      // ignore: invalid_use_of_internal_member
      timestamp: _options.clock(),
    ));
  }

/*
  These are also methods of `WidgetsBindingObserver` but are currently not
  implemented because I'm not sure what to do with them. See the reasoning
  for each method. If these methods are implemented the class definition should
  be changed from `class SentryWidgetsBindingObserver with WidgetsBindingObserver`
  to `class SentryWidgetsBindingObserver implements WidgetsBindingObserver`.
  You should also add options SentryFlutterOptions to configure if these
  events should be tracked.

  // Figure out which accessibility features changed
  @override
  void didChangeAccessibilityFeatures() {}

  // Figure out which locales changed
  @override
  void didChangeLocales(List<Locale> locale) {}

  // Does this need to be considered?
  // On the one side this is already included in the SentryNavigatorObserver
  // but on the other side, SentryNavigatorObserver must be manually added by
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
