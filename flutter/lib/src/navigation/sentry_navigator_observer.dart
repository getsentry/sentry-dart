import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';
import '../../sentry_flutter.dart';

/// This key must be used so that the web interface displays the events nicely
/// See https://develop.sentry.dev/sdk/event-payloads/breadcrumbs/
const _navigationKey = 'navigation';

/// Used as value for [SentrySpanContext.operation]
const _transactionOp = 'ui.load';

/// This is a navigation observer to record navigational breadcrumbs.
/// For now it only records navigation events and no gestures.
///
/// [Route]s can always be null and their [Route.settings] can also always be null.
/// For example, if the application starts, there is no previous route.
/// The [RouteSettings] is null if a developer has not specified any
/// RouteSettings.
///
/// [SentryNavigatorObserver] must be added to the [navigation observer](https://api.flutter.dev/flutter/material/MaterialApp/navigatorObservers.html) of
/// your used app. This is an example for [MaterialApp](https://api.flutter.dev/flutter/material/MaterialApp/navigatorObservers.html),
/// but the integration for [CupertinoApp](https://api.flutter.dev/flutter/cupertino/CupertinoApp/navigatorObservers.html)
/// and [WidgetsApp](https://api.flutter.dev/flutter/widgets/WidgetsApp/navigatorObservers.html) is the same.
///
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:sentry_flutter/sentry_flutter.dart';
///
/// MaterialApp(
///   navigatorObservers: [
///     SentryNavigatorObserver(),
///   ],
///   // other parameter ...
/// )
/// ```
///
/// See also:
///   - [RouteObserver](https://api.flutter.dev/flutter/widgets/RouteObserver-class.html)
///   - [Navigating with arguments](https://flutter.dev/docs/cookbook/navigation/navigate-with-arguments)
class SentryNavigatorObserver extends RouteObserver<PageRoute<dynamic>> {
  SentryNavigatorObserver({Hub? hub, this.enableTracing = false})
      : hub = hub ?? HubAdapter();

  final Hub hub;

  /// Create a new transaction, which gets bound to the scope, on each
  /// navigation event.
  /// [RouteSettings] are added as extras. The [RouteSettings.name] is used as
  /// a name.
  final bool enableTracing;

  ISentrySpan? _currentTransaction;
  ISentrySpan? _currentSpan;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _addBreadcrumb(
      type: 'didPush',
      from: previousRoute?.settings,
      to: route.settings,
    );
    if (route is PopupRoute) {
      _startSpan(route);
    } else {
      _startTrace(route);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    _addBreadcrumb(
      type: 'didReplace',
      from: oldRoute?.settings,
      to: newRoute?.settings,
    );
    if (oldRoute is ModalRoute) {
      _currentSpan?.finish();
    }
    if (newRoute is PopupRoute) {
      _startSpan(newRoute);
    } else {
      _startTrace(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    _addBreadcrumb(
      type: 'didPop',
      from: route.settings,
      to: previousRoute?.settings,
    );
    if (previousRoute is ModalRoute) {
      _currentSpan?.finish();
    }
    _startTrace(previousRoute);
  }

  void _addBreadcrumb({
    required String type,
    RouteSettings? from,
    RouteSettings? to,
  }) {
    hub.addBreadcrumb(RouteObserverBreadcrumb(
      navigationType: type,
      from: from,
      to: to,
    ));
  }

  Future<void> _startTrace(Route? route) async {
    if (!enableTracing) {
      return;
    }
    await _currentTransaction?.finish();

    var span = hub.startTransaction(
      route?.settings.name ?? 'unnamed page',
      _transactionOp,
      bindToScope: true,
    );

    final arguments = route?.settings.arguments;
    if (arguments != null) {
      span.setData('route_settings_arguments', arguments);
    }

    _currentTransaction = span;
  }

  Future<void> _startSpan(PopupRoute? route) async {
    if (!enableTracing) {
      return;
    }
    await _currentSpan?.finish();
    final span = _currentTransaction?.startChild(
      _transactionOp,
      description: route?.settings.name ?? 'unnamed popup',
    );
    final arguments = route?.settings.arguments;
    if (arguments != null) {
      span?.setData('route_settings_arguments', arguments);
    }
    _currentSpan = span;
  }
}

/// This class makes it easier to record breadcrumbs for events of Flutters
/// NavigationObserver by accepting
/// [RouteSettings].
///
/// See also:
///   - [Navigating with arguments](https://flutter.dev/docs/cookbook/navigation/navigate-with-arguments)
class RouteObserverBreadcrumb extends Breadcrumb {
  factory RouteObserverBreadcrumb({
    /// This should correspond to Flutters navigation events.
    /// See https://api.flutter.dev/flutter/widgets/RouteObserver-class.html
    required String navigationType,
    RouteSettings? from,
    RouteSettings? to,
    SentryLevel? level,
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
    required String navigationType,
    String? from,
    dynamic fromArgs,
    String? to,
    dynamic toArgs,
    SentryLevel? level,
  }) : super(
            category: _navigationKey,
            type: _navigationKey,
            level: level,
            data: <String, dynamic>{
              'state': navigationType,
              if (from != null) 'from': from,
              if (fromArgs != null) 'from_arguments': fromArgs,
              if (to != null) 'to': to,
              if (toArgs != null) 'to_arguments': toArgs,
            });

  static dynamic _formatArgs(Object? args) {
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
