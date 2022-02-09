import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/sentry_native_wrapper.dart';
import '../../sentry_flutter.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

/// This key must be used so that the web interface displays the events nicely
/// See https://develop.sentry.dev/sdk/event-payloads/breadcrumbs/
const _navigationKey = 'navigation';

typedef RouteNameExtractor = RouteSettings? Function(RouteSettings? settings);

typedef AdditionalInfoExtractor = Map<String, dynamic>? Function(
  RouteSettings? from,
  RouteSettings? to,
);

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
/// The option [enableAutoTransactions] is enabled by default. For every new
/// route a transaction is started. It's automatically finished after
/// [autoFinishAfter] duration or when all child spans are finished,
/// if those happen to take longer. The transaction will be set to [Scope.span]
/// if the latter is empty.
///
/// Enabling the [setRouteNameAsTransaction] option overrides the current
/// [Scope.transaction] which will also override the name of the current
/// [Scope.span]. So be careful when this is used together with performance
/// monitoring.
///
/// Setting [enableAppStartTracking] will track the app start time by adding
/// measurements to the first route transaction. If there is no routing
/// instrumentation an app start transaction will be started.
///
/// See also:
///   - [RouteObserver](https://api.flutter.dev/flutter/widgets/RouteObserver-class.html)
///   - [Navigating with arguments](https://flutter.dev/docs/cookbook/navigation/navigate-with-arguments)
class SentryNavigatorObserver extends RouteObserver<PageRoute<dynamic>> {
  SentryNavigatorObserver({
    Hub? hub,
    bool enableAutoTransactions = true,
    Duration autoFinishAfter = const Duration(seconds: 3),
    bool setRouteNameAsTransaction = false,
    bool enableAppStartTracking = true,
    RouteNameExtractor? routeNameExtractor,
    AdditionalInfoExtractor? additionalInfoProvider,
  })  : _hub = hub ?? HubAdapter(),
        _enableAutoTransactions = enableAutoTransactions,
        _autoFinishAfter = autoFinishAfter,
        _setRouteNameAsTransaction = setRouteNameAsTransaction,
        _enableAppStartTracking = enableAppStartTracking,
        _routeNameExtractor = routeNameExtractor,
        _additionalInfoProvider = additionalInfoProvider;

  final Hub _hub;
  final bool _enableAutoTransactions;
  final Duration _autoFinishAfter;
  final bool _setRouteNameAsTransaction;
  final bool _enableAppStartTracking;
  final RouteNameExtractor? _routeNameExtractor;
  final AdditionalInfoExtractor? _additionalInfoProvider;

  ISentrySpan? _transaction;
  DateTime? _appStartFinishTime;
  NativeAppStart? _nativeAppStart;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) async {
    super.didPush(route, previousRoute);

    await _instrumentAppStart();

    _setCurrentRoute(route.settings.name);
    _addBreadcrumb(
      type: 'didPush',
      from: previousRoute?.settings,
      to: route.settings,
    );

    await _finishTransaction();

    _startTransaction(route.settings.name, route.settings.arguments);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _setCurrentRoute(newRoute?.settings.name);
    _addBreadcrumb(
      type: 'didReplace',
      from: oldRoute?.settings,
      to: newRoute?.settings,
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _setCurrentRoute(previousRoute?.settings.name);
    _addBreadcrumb(
      type: 'didPop',
      from: route.settings,
      to: previousRoute?.settings,
    );
    _finishTransaction();
    _startTransaction(
      previousRoute?.settings.name,
      previousRoute?.settings.arguments,
    );
  }

  Future<void> _instrumentAppStart() async {
    if (!_enableAppStartTracking || _appStartFinishTime != null) {
      return;
    }
    _appStartFinishTime = DateTime.now(); // TODO: Set correct app start timestamp
    _nativeAppStart = await SentryFlutter.native.fetchNativeAppStart();
  }

  SentryMeasurement _measurementFrom(NativeAppStart nativeAppStart, DateTime appStartFinishTime) {
    final appStartTime = DateTime.fromMillisecondsSinceEpoch(nativeAppStart.appStartTime.toInt());
    final duration = appStartFinishTime.difference(appStartTime);

    return nativeAppStart.isColdStart
        ? SentryMeasurement.coldAppStart(duration)
        : SentryMeasurement.warmAppStart(duration);
  }

  void _addBreadcrumb({
    required String type,
    RouteSettings? from,
    RouteSettings? to,
  }) {
    _hub.addBreadcrumb(RouteObserverBreadcrumb(
      navigationType: type,
      from: _routeNameExtractor?.call(from) ?? from,
      to: _routeNameExtractor?.call(to) ?? to,
      data: _additionalInfoProvider?.call(from, to),
    ));
  }

  void _setCurrentRoute(String? name) {
    if (name == null) {
      return;
    }
    if (_setRouteNameAsTransaction) {
      _hub.configureScope((scope) {
        scope.transaction = name;
      });
    }
  }

  void _startTransaction(String? name, Object? arguments) {
    if (!_enableAutoTransactions) {
      return;
    }
    if (name == null) {
      return;
    }

    final isRoot = name == '/';
    if (isRoot) {
      name = 'root ("/")';
    }

    _transaction = _hub.startTransaction(
      name,
      'navigation',
      waitForChildren: true,
      autoFinishAfter: _autoFinishAfter,
      trimEnd: true,
    );

    if (arguments != null) {
      _transaction?.setData('route_settings_arguments', arguments);
    }

    _hub.configureScope((scope) {
      scope.span ??= _transaction;
    });

    if (isRoot) {
      _addAppStartData(_transaction);
    }
  }

  void _addAppStartData(ISentrySpan? transaction) {
    // ignore: invalid_use_of_internal_member
    if (transaction is SentryTracer) {
      // ignore: invalid_use_of_internal_member
      final tracer = transaction as SentryTracer;
      final nativeAppStart = _nativeAppStart;
      final appStartFinishTime = _appStartFinishTime;

      if (nativeAppStart != null && appStartFinishTime != null) {

        // TODO(denrase): Add app start child span when we are able to provide
        // custom start/end timestamps.

        final appStartMeasurement = _measurementFrom(nativeAppStart, appStartFinishTime);
        tracer.addMeasurement(appStartMeasurement);
      }
    }
  }

  Future<void> _finishTransaction() async {
    _transaction?.status ??= SpanStatus.ok();
    return await _transaction?.finish();
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
    Map<String, dynamic>? data,
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
      data: data,
    );
  }

  RouteObserverBreadcrumb._({
    required String navigationType,
    String? from,
    dynamic fromArgs,
    String? to,
    dynamic toArgs,
    SentryLevel? level,
    Map<String, dynamic>? data,
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
              if (data != null) 'data': data,
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
