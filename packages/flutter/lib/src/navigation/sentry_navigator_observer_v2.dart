// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter/material.dart';

import '../../sentry_flutter.dart';
import '../display/display_handles.dart';
import '../display/display_txn.dart';
import '../frame_callback_handler.dart';

/// Experimental V2 navigator observer wiring the new display timing controller/engine.
///
/// This class is side-by-side with the legacy [SentryNavigatorObserver] and can
/// be opted into explicitly. It keeps breadcrumbs/web-session logic out for now
/// per the refactor plan, focusing only on TTID/TTFD via the controller.
class SentryNavigatorObserverV2 extends RouteObserver<PageRoute<dynamic>> {
  SentryNavigatorObserverV2({
    Hub? hub,
    FrameCallbackHandler? frameHandler,
    List<String>? ignoreRoutes,
  })  : _hub = hub ?? HubAdapter(),
        _frameHandler = frameHandler ?? DefaultFrameCallbackHandler(),
        _ignoreRoutes = ignoreRoutes ?? [] {
    _isCreated = true;
  }

  final Hub _hub;
  final FrameCallbackHandler _frameHandler;
  final List<String> _ignoreRoutes;

  static bool _isCreated = false;
  static bool get isCreated => _isCreated;

  RouteDisplayHandle? _currentRouteHandle;

  bool _isRouteIgnored(Route<dynamic> route) {
    final name = route.settings.name;
    return name != null && _ignoreRoutes.contains(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    if (_isRouteIgnored(route) ||
        (previousRoute != null && _isRouteIgnored(previousRoute))) {
      return;
    }

    final options = _hub.options;
    if (options is! SentryFlutterOptions) {
      return;
    }
    if (!options.experimentalUseDisplayTimingV2) {
      return;
    }

    final routeName = route.settings.name;
    if (routeName == null || routeName == '/') {
      // root handled by app-start integration V2
      return;
    }

    if (options.enableAutoPerformanceTracing) {
      _hub.generateNewTrace();
    }

    final now = options.clock();
    _currentRouteHandle = options.displayTiming.startRoute(
      name: routeName,
      arguments: route.settings.arguments,
      now: now,
      autoFinishAfter: options.displayAutoFinishAfter,
    );

    // Synchronously queue a post-frame callback to end TTID on first completed frame
    final handle = _currentRouteHandle!;
    _frameHandler.addPostFrameCallback((_) {
      handle.endTtid(options.clock());
    });
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    final options = _hub.options;
    if (options is! SentryFlutterOptions) {
      return;
    }
    if (!options.experimentalUseDisplayTimingV2) {
      return;
    }

    if (_isRouteIgnored(route) ||
        (previousRoute != null && _isRouteIgnored(previousRoute))) {
      return;
    }

    options.displayTiming
        .abortCurrent(slot: DisplaySlot.route, when: options.clock());
    _currentRouteHandle = null;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    final options = _hub.options;
    if (options is! SentryFlutterOptions) {
      return;
    }
    if (!options.experimentalUseDisplayTimingV2) {
      return;
    }

    if (newRoute != null && _isRouteIgnored(newRoute) ||
        oldRoute != null && _isRouteIgnored(oldRoute)) {
      return;
    }

    final routeName = newRoute?.settings.name;
    if (routeName == null || routeName == '/') {
      return;
    }

    if (options.enableAutoPerformanceTracing) {
      _hub.generateNewTrace();
    }
    final now = options.clock();
    _currentRouteHandle = options.displayTiming.startRoute(
      name: routeName,
      arguments: newRoute?.settings.arguments,
      now: now,
      autoFinishAfter: options.displayAutoFinishAfter,
    );

    final handle = _currentRouteHandle!;
    _frameHandler.addPostFrameCallback((_) {
      handle.endTtid(options.clock());
    });
  }
}
