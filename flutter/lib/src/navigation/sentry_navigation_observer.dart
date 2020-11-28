import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// This is a navigation observer to record navigational breadcrumbs.
/// For now it only records navigation events and no gestures.
///
/// Routes can always be null and their settings can also always be null.
/// For example, if the application starts, there is no previous route.
/// The RouteSettings are null if a developer has not specified any
/// RouteSettings.
///
/// SentryNavigationObserver must be added to the navigation observer of
/// your used app. This is an example for [MaterialApp](https://api.flutter.dev/flutter/material/MaterialApp/navigatorObservers.html),
/// but the integration for [CupertinoApp](https://api.flutter.dev/flutter/cupertino/CupertinoApp/navigatorObservers.html)
/// and [WidgetsApp](https://api.flutter.dev/flutter/widgets/WidgetsApp/navigatorObservers.html) is the same.
/// ´´´dart
/// MaterialApp(
///   navigatorObservers: [
///     SentryNavigatorObserver(),
///   ],
///   // other parameter ...
/// )
/// ´´´
///
/// See also:
///   - https://api.flutter.dev/flutter/widgets/RouteObserver-class.html
class SentryNavigatorObserver extends RouteObserver<PageRoute<dynamic>> {
  factory SentryNavigatorObserver({Hub hub}) {
    return SentryNavigatorObserver._(hub ?? HubAdapter());
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
      navigationType: type,
      from: from,
      to: to,
    ));
  }
}
