import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';

import 'navigation_breadcrumb.dart';

/// This is a navigation observer to record navigational breadcrumbs.
/// For now it only records navigation events and no gestures.
///
/// Routes can always be null and their settings can also always be null.
/// For example, if the application starts, there is no previous route.
/// The RouteSettings are null if a developer has not specified any
/// RouteSettings.
///
/// See also:
///   - https://api.flutter.dev/flutter/widgets/RouteObserver-class.html
class SentryNavigatorObserver extends RouteObserver<PageRoute<dynamic>> {
  factory SentryNavigatorObserver(Hub hub) {
    if (hub != null) {
      return SentryNavigatorObserver._(hub);
    }
    return SentryNavigatorObserver._(Sentry.currentHub);
  }

  SentryNavigatorObserver._(this.hub) : assert(hub != null);

  final Hub hub;

  @override
  void didPush(Route<dynamic> route, Route<dynamic> previousRoute) {
    super.didPush(route, previousRoute);
    _addBreadcrumb(
      type: 'didPush',
      from: previousRoute?.settings,
      to: route?.settings,
    );
  }

  @override
  void didReplace({Route<dynamic> newRoute, Route<dynamic> oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    _addBreadcrumb(
      type: 'didReplace',
      from: oldRoute?.settings,
      to: newRoute?.settings,
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic> previousRoute) {
    super.didPop(route, previousRoute);

    _addBreadcrumb(
      type: 'didPop',
      from: route?.settings,
      to: previousRoute?.settings,
    );
  }

  void _addBreadcrumb({
    String type,
    RouteSettings from,
    RouteSettings to,
  }) {
    hub.addBreadcrumb(NavigationBreadcrumb(
      from: from,
      to: to,
      navigationType: type,
    ));
  }
}
