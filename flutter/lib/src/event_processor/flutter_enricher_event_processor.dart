import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry/sentry.dart';

import '../navigation/sentry_navigator_observer.dart';
import '../sentry_flutter_options.dart';

typedef WidgetBindingGetter = WidgetsBinding? Function();

/// Enriches [SentryEvent]s with various kinds of information.
/// FlutterEnricher only needs to add information which aren't exposed by
/// the Dart runtime.
class FlutterEnricherEventProcessor implements EventProcessor {
  FlutterEnricherEventProcessor(this._options);

  final SentryFlutterOptions _options;

  bool get _hasNativeIntegration => _checker.hasNativeIntegration;
  PlatformChecker get _checker => _options.platformChecker;

  // We can't use `WidgetsBinding` as a direct parameter
  // because it must be called inside the `runZoneGuarded`-Integration.
  // Thus we call it on demand after all the initialization happened.
  WidgetsBinding? get _widgetsBinding => _options.bindingUtils.instance;

  // ignore: deprecated_member_use
  SingletonFlutterWindow? get _window => _widgetsBinding?.window;
  Map<String, String> _packages = {};

  @override
  Future<SentryEvent?> apply(
    SentryEvent event,
    Hint hint,
  ) async {
    // If there's a native integration available, it probably has better
    // information available than Flutter.
    final device =
        _hasNativeIntegration ? null : _getDevice(event.contexts.device);

    final contexts = event.contexts.copyWith(
      device: device,
      runtimes: _getRuntimes(event.contexts.runtimes),
      culture: _getCulture(event.contexts.culture),
      operatingSystem: _getOperatingSystem(event.contexts.operatingSystem),
      app: _getApp(event.contexts.app),
    );

    final app = contexts.app;
    if (app != null) {
      contexts.app = _appWithCurrentRouteViewName(app);
    }

    // Flutter has a lot of Accessibility Settings available and exposes them
    contexts['accessibility'] = _getAccessibilityContext();

    // Conflicts with Flutter runtime if it's just called `Flutter`
    contexts['flutter_context'] = _getFlutterContext();

    event = event.copyWith(
      contexts: contexts,
    );

    if (event is! SentryTransaction) {
      event = event.copyWith(
        modules: await _getPackages(),
      );
    }
    return event;
  }

  /// Packages are loaded from [LicenseRegistry].
  /// This is currently the only way to know which packages are used.
  /// This however has some drawbacks:
  /// - Only packages with licenses are known
  /// - No version information is available
  /// - Flutter's native dependencies are also included.
  Future<Map<String, String>?> _getPackages() async {
    if (!_options.reportPackages) {
      return null;
    }
    if (_packages.isEmpty) {
      // This can take some time.
      // Therefore we cache this after running
      var packages = <String>{};
      // The license registry has a list of licenses entries (MIT, Apache...).
      // Each license entry has a list of packages which licensed under this particular license.
      // Libraries can be dual licensed.
      //
      // We don't care about those license issues, we just want each package name once.
      // Therefore we add each name to a set to make sure we only add it once.
      await LicenseRegistry.licenses.forEach(
        (entry) => packages.addAll(
          entry.packages.toList(),
        ),
      );

      _packages = Map.fromEntries(
        packages.map(
          (e) => MapEntry(e, 'unknown'),
        ),
      );
    }
    return _packages;
  }

  SentryCulture _getCulture(SentryCulture? culture) {
    final windowLanguageTag = _window?.locale.toLanguageTag();
    final screenLocale = _retrieveWidgetLocale(_options.navigatorKey);
    final languageTag = screenLocale?.toLanguageTag() ?? windowLanguageTag;

    // Future enhancement:
    // _window?.locales

    return (culture ?? SentryCulture()).copyWith(
      is24HourFormat: culture?.is24HourFormat ?? _window?.alwaysUse24HourFormat,
      locale: culture?.locale ?? languageTag,
      timezone: culture?.timezone ?? DateTime.now().timeZoneName,
    );
  }

  Map<String, String> _getFlutterContext() {
    final currentLifecycle = _widgetsBinding?.lifecycleState;
    final debugPlatformOverride = debugDefaultTargetPlatformOverride;
    final tempDebugBrightnessOverride = debugBrightnessOverride;
    final initialLifecycleState = _window?.initialLifecycleState;
    final defaultRouteName = _window?.defaultRouteName;
    // A FlutterEngine has no renderViewElement if it was started or is
    // accessed from an isolate different to the main isolate.

    // to keep compatibility with older versions
    // ignore: deprecated_member_use
    final hasRenderView = _widgetsBinding?.renderViewElement != null;

    final renderer = _options.rendererWrapper.getRenderer()?.name;

    return <String, String>{
      'has_render_view': hasRenderView.toString(),
      if (tempDebugBrightnessOverride != null)
        'debug_brightness_override': tempDebugBrightnessOverride.name,
      if (debugPlatformOverride != null)
        'debug_default_target_platform_override': debugPlatformOverride.name,
      if (initialLifecycleState != null && initialLifecycleState.isNotEmpty)
        'initial_lifecycle_state': initialLifecycleState,
      if (defaultRouteName != null && defaultRouteName.isNotEmpty)
        'default_route_name': defaultRouteName,
      if (currentLifecycle != null)
        'current_lifecycle_state': currentLifecycle.name,
      // Seems to always return false.
      // Also always fails in tests.
      // See https://github.com/flutter/flutter/issues/83919
      // 'window_is_visible': _window.viewConfiguration.visible,
      if (renderer != null) 'renderer': renderer,
      if (_appFlavor != null) 'appFlavor': _appFlavor!,
    };
  }

  Map<String, bool> _getAccessibilityContext() {
    final window = _window;
    if (window == null) {
      return {};
    }
    return <String, bool>{
      'accessible_navigation':
          window.accessibilityFeatures.accessibleNavigation,
      'bold_text': window.accessibilityFeatures.boldText,
      'disable_animations': window.accessibilityFeatures.disableAnimations,
      'high_contrast': window.accessibilityFeatures.highContrast,
      'invert_colors': window.accessibilityFeatures.invertColors,
      'reduce_motion': window.accessibilityFeatures.reduceMotion,
    };
  }

  SentryDevice? _getDevice(SentryDevice? device) {
    final window = _window;
    if (window == null) {
      return device;
    }
    final orientation = window.physicalSize.width > window.physicalSize.height
        ? SentryOrientation.landscape
        : SentryOrientation.portrait;

    return (device ?? SentryDevice()).copyWith(
      orientation: device?.orientation ?? orientation,
      screenHeightPixels:
          device?.screenHeightPixels ?? window.physicalSize.height.toInt(),
      screenWidthPixels:
          device?.screenWidthPixels ?? window.physicalSize.width.toInt(),
      screenDensity: device?.screenDensity ?? window.devicePixelRatio,
    );
  }

  SentryOperatingSystem _getOperatingSystem(SentryOperatingSystem? os) {
    return (os ?? SentryOperatingSystem()).copyWith(
      // ignore: deprecated_member_use
      theme: os?.theme ?? describeEnum(window.platformBrightness),
    );
  }

  List<SentryRuntime> _getRuntimes(List<SentryRuntime>? runtimes) {
    var compiler = '';

    // See
    // - https://flutter.dev/docs/testing/build-modes
    // - https://github.com/flutter/flutter/wiki/Flutter%27s-modes
    if (_checker.isWeb) {
      if (_checker.isDebugMode()) {
        compiler = 'dartdevc';
      } else if (_checker.isReleaseMode() || _checker.isProfileMode()) {
        compiler = 'dart2js';
      }
    } else {
      if (_checker.isDebugMode()) {
        compiler = 'Dart VM';
      } else if (_checker.isReleaseMode() || _checker.isProfileMode()) {
        compiler = 'Dart AOT';
      }
    }

    final flutterRuntime = SentryRuntime(
      name: 'Flutter',
      compiler: compiler,
    );

    if (runtimes == null || runtimes.isEmpty) {
      return [flutterRuntime];
    }

    return [
      ...runtimes,
      flutterRuntime,
    ];
  }

  SentryApp? _getApp(SentryApp? app) {
    final currentLifecycle = _widgetsBinding?.lifecycleState;
    if (currentLifecycle == null) {
      return app;
    }

    // See 'flutter_context' for more detailed app state.
    final inForeground = currentLifecycle == AppLifecycleState.resumed;

    return (app ?? SentryApp()).copyWith(
      inForeground: inForeground,
    );
  }

  SentryApp _appWithCurrentRouteViewName(SentryApp app) {
    final currentRouteName = SentryNavigatorObserver.currentRouteName;
    if (currentRouteName != null) {
      final viewNames = app.viewNames ?? [];
      viewNames.add(currentRouteName);
      return app.copyWith(viewNames: viewNames);
    } else {
      return app;
    }
  }

  Locale? _retrieveWidgetLocale(GlobalKey<NavigatorState>? navigatorKey) {
    final BuildContext? context = navigatorKey?.currentContext;
    if (context != null) {
      return Localizations.maybeLocaleOf(context);
    }
    return null;
  }
}

/// Copied from https://api.flutter.dev/flutter/services/appFlavor-constant.html
/// As soon as Flutter 3.16 is the minimal supported version of Sentry, this
/// can be replaced with the property from the link above.
const String? _appFlavor = String.fromEnvironment('FLUTTER_APP_FLAVOR') != ''
    ? String.fromEnvironment('FLUTTER_APP_FLAVOR')
    : null;
