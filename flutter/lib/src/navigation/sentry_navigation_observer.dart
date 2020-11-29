import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// This key must be used so that the web interface displays the events nicely
/// See https://develop.sentry.dev/sdk/event-payloads/breadcrumbs/
const _navigationKey = 'navigation';

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
///
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
///   - https://flutter.dev/docs/cookbook/navigation/navigate-with-arguments
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
    hub.addBreadcrumb(RouteObserverBreadcrumb(
      navigationType: type,
      from: from,
      to: to,
    ));
  }
}

/// This class makes it easier to record breadcrumbs for events of Flutters
/// NavigationObserver by accepting
/// [RouteSettings](https://api.flutter.dev/flutter/widgets/RouteSettings-class.html).
///
/// See also:
///   - https://flutter.dev/docs/cookbook/navigation/navigate-with-arguments
class RouteObserverBreadcrumb extends Breadcrumb {
  factory RouteObserverBreadcrumb({
    /// This should correspond to Flutters navigation events.
    /// See https://api.flutter.dev/flutter/widgets/RouteObserver-class.html
    @required String navigationType,
    RouteSettings from,
    RouteSettings to,
    SentryLevel level = SentryLevel.info,
  }) {
    final dynamic fromArgs = _formatArgs(from?.arguments);
    final dynamic toArgs = _formatArgs(to?.arguments);
    return RouteObserverBreadcrumb._(
      from: from?.name,
      fromArgs: fromArgs,
      to: to?.name,
      toArgs: toArgs,
      navigationType: navigationType,
      level: level,
    );
  }

  RouteObserverBreadcrumb._({
    @required String navigationType,
    String from,
    dynamic fromArgs,
    String to,
    dynamic toArgs,
    SentryLevel level = SentryLevel.info,
  })  : assert(navigationType != null),
        super(
            category: _navigationKey,
            type: _navigationKey,
            level: level,
            data: <String, dynamic>{
              if (navigationType != null) 'state': navigationType,
              if (from != null) 'from': from,
              if (fromArgs != null) 'from_arguments': fromArgs,
              if (to != null) 'to': to,
              if (toArgs != null) 'to_arguments': toArgs,
            });

  static dynamic _formatArgs(Object args) {
    if (args == null) {
      return null;
    }
    if (args is Map<String, dynamic>) {
      return args.map<String, dynamic>((key, dynamic value) =>
          MapEntry<String, String>(key, value.toString()));
    }
    return args.toString();
  }
}
