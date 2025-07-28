// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

import '../../sentry_flutter.dart';
import '../event_processor/flutter_enricher_event_processor.dart';
import '../integrations/web_session_integration.dart';
import '../web/web_session_handler.dart';
import 'time_to_display_tracker.dart';

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
/// It also records Time to Initial Display (TTID).
///
/// [Route]s can always be null and their [Route.settings] can also always be null.
/// For example, if the application starts, there is no previous route.
/// The [RouteSettings] is null if a developer has not specified any
/// RouteSettings.
///
/// The current route name will also be set to [SentryEvent]
/// `contexts.app.view_names` by [FlutterEnricherEventProcessor].
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
/// If [enableNewTraceOnNavigation] is true (default), a
/// fresh trace is generated before each push, pop, or replace event.
///
/// Enabling the [setRouteNameAsTransaction] option overrides the current
/// [Scope.transaction] which will also override the name of the current
/// [Scope.span]. So be careful when this is used together with performance
/// monitoring.
///
/// See also:
///   - [RouteObserver](https://api.flutter.dev/flutter/widgets/RouteObserver-class.html)
///   - [Navigating with arguments](https://flutter.dev/docs/cookbook/navigation/navigate-with-arguments)
class SentryNavigatorObserver extends RouteObserver<PageRoute<dynamic>> {
  SentryNavigatorObserver({
    Hub? hub,
    bool enableAutoTransactions = true,
    bool enableNewTraceOnNavigation = true,
    Duration autoFinishAfter = const Duration(seconds: 3),
    bool setRouteNameAsTransaction = false,
    RouteNameExtractor? routeNameExtractor,
    AdditionalInfoExtractor? additionalInfoProvider,
    List<String>? ignoreRoutes,
  })  : _hub = hub ?? HubAdapter(),
        _enableAutoTransactions = enableAutoTransactions,
        _enableNewTraceOnNavigation = enableNewTraceOnNavigation,
        _autoFinishAfter = autoFinishAfter,
        _setRouteNameAsTransaction = setRouteNameAsTransaction,
        _routeNameExtractor = routeNameExtractor,
        _additionalInfoProvider = additionalInfoProvider,
        _ignoreRoutes = ignoreRoutes ?? [] {
    _isCreated = true;
    if (enableAutoTransactions) {
      _hub.options.sdk.addIntegration('UINavigationTracing');
    }
    _timeToDisplayTracker = _initializeTimeToDisplayTracker();
    final webSessionIntegration = _hub.options.integrations
        .whereType<WebSessionIntegration>()
        .firstOrNull;
    webSessionIntegration?.enable();
    _webSessionHandler = webSessionIntegration?.webSessionHandler;
  }

  /// Initializes the TimeToDisplayTracker with the option to enable time to full display tracing.
  TimeToDisplayTracker? _initializeTimeToDisplayTracker() {
    final options = _hub.options;
    if (options is SentryFlutterOptions) {
      return options.timeToDisplayTracker;
    } else {
      return null;
    }
  }

  final Hub _hub;
  final bool _enableAutoTransactions;
  final bool _enableNewTraceOnNavigation;
  final Duration _autoFinishAfter;
  final bool _setRouteNameAsTransaction;
  final RouteNameExtractor? _routeNameExtractor;
  final AdditionalInfoExtractor? _additionalInfoProvider;
  final List<String> _ignoreRoutes;
  TimeToDisplayTracker? _timeToDisplayTracker;

  WebSessionHandler? _webSessionHandler;

  @visibleForTesting
  WebSessionHandler? get webSessionHandler => _webSessionHandler;

  ISentrySpan? _transaction;

  static String? _currentRouteName;

  @internal
  static String? get currentRouteName => _currentRouteName;

  static bool _isCreated = false;

  @internal
  static bool get isCreated => _isCreated;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    if (_isRouteIgnored(route) ||
        previousRoute != null && _isRouteIgnored(previousRoute)) {
      return;
    }

    _setCurrentRouteName(route);
    _setCurrentRouteNameAsTransaction(route);

    _addBreadcrumb(
      type: 'didPush',
      from: previousRoute?.settings,
      to: route.settings,
    );

    _addWebSessions(from: previousRoute, to: route);

    final routeName = _getRouteName(route) ?? _currentRouteName;
    if (routeName != null && routeName != '/') {
      // Don't generate a new trace on initial app start / root
      // During SentryFlutter.init a traceId is already created
      _startNewTraceIfEnabled();

      // App start TTID/TTFD is taken care of by app start integrations
      _instrumentTimeToDisplayOnPush(routeName, route.settings.arguments);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    if (newRoute != null && _isRouteIgnored(newRoute) ||
        oldRoute != null && _isRouteIgnored(oldRoute)) {
      return;
    }

    _startNewTraceIfEnabled();
    _setCurrentRouteName(newRoute);
    _setCurrentRouteNameAsTransaction(newRoute);

    _addBreadcrumb(
      type: 'didReplace',
      from: oldRoute?.settings,
      to: newRoute?.settings,
    );

    _addWebSessions(from: oldRoute, to: newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    if (_isRouteIgnored(route) ||
        previousRoute != null && _isRouteIgnored(previousRoute)) {
      return;
    }

    _startNewTraceIfEnabled();
    _setCurrentRouteName(previousRoute);
    _setCurrentRouteNameAsTransaction(previousRoute);

    _addBreadcrumb(
      type: 'didPop',
      from: route.settings,
      to: previousRoute?.settings,
    );

    _addWebSessions(from: route, to: previousRoute);

    final timestamp = _hub.options.clock();
    _finishTransaction(endTimestamp: timestamp);
  }

  void _startNewTraceIfEnabled() {
    if (_enableNewTraceOnNavigation) {
      _hub.generateNewTrace();
    }
  }

  void _instrumentTimeToDisplayOnPush(String routeName, Object? arguments) {
    if (!_enableAutoTransactions) {
      return;
    }

    // Clearing the display tracker here is safe since didPush happens before the Widget is built
    _timeToDisplayTracker?.clear();

    DateTime timestamp = _hub.options.clock();
    _finishTransaction(endTimestamp: timestamp);

    final transactionContext = _createTransactionContext(routeName);
    _startTransaction(timestamp, transactionContext, arguments);
  }

  void _addWebSessions({Route<dynamic>? from, Route<dynamic>? to}) async {
    final fromName = from != null ? _getRouteName(from) : null;
    final toName = to != null ? _getRouteName(to) : null;

    await _webSessionHandler?.startSession(from: fromName, to: toName);
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
      timestamp: _hub.options.clock(),
      data: _additionalInfoProvider?.call(from, to),
    ));
  }

  String? _getRouteName(Route<dynamic>? route) {
    return (_routeNameExtractor?.call(route?.settings) ?? route?.settings)
        ?.name;
  }

  Future<void> _setCurrentRouteName(Route<dynamic>? route) async {
    _currentRouteName = _getRouteName(route);
  }

  Future<void> _setCurrentRouteNameAsTransaction(Route<dynamic>? route) async {
    final name = _getRouteName(route);
    if (name == null) {
      return;
    }
    if (_setRouteNameAsTransaction) {
      await _hub.configureScope((scope) {
        scope.transaction = name;
      });
    }
  }

  SentryTransactionContext _createTransactionContext(String routeName) {
    return SentryTransactionContext(
      routeName,
      SentrySpanOperations.uiLoad,
      transactionNameSource: SentryTransactionNameSource.component,
      origin: SentryTraceOrigins.autoNavigationRouteObserver,
    );
  }

  Future<void> _startTransaction(
    DateTime startTimestamp,
    SentryTransactionContext transactionContext,
    Object? arguments,
  ) async {
    _timeToDisplayTracker?.transactionId = transactionContext.spanId;

    final transaction = _hub.startTransactionWithContext(
      transactionContext,
      startTimestamp: startTimestamp,
      waitForChildren: true,
      autoFinishAfter: _autoFinishAfter,
      trimEnd: true,
      onFinish: (transaction) async {
        _transaction = null;
      },
    );
    // if _enableAutoTransactions is enabled but there's no traces sample rate
    if (transaction is NoOpSentrySpan) {
      _timeToDisplayTracker?.transactionId = null;
      return;
    }

    if (arguments != null) {
      transaction.setData('route_settings_arguments', arguments);
    }

    _transaction = transaction;

    await _hub.configureScope((scope) {
      scope.span ??= _transaction;
    });

    await _timeToDisplayTracker?.track(transaction);
  }

  Future<void> _finishTransaction({required DateTime endTimestamp}) async {
    final transaction = _transaction;
    _transaction = null;
    try {
      _hub.configureScope((scope) {
        if (transaction != null && scope.span == transaction) {
          scope.span = null;
        }
      });

      if (transaction == null || transaction.finished) {
        return;
      }
      if (transaction is SentryTracer) {
        await _timeToDisplayTracker?.cancelUnfinishedSpans(
          transaction,
          endTimestamp,
        );
      }
    } catch (exception, stacktrace) {
      _hub.options.log(
        SentryLevel.error,
        'Error while finishing transaction',
        exception: exception,
        stackTrace: stacktrace,
      );
      if (_hub.options.automatedTestMode) {
        rethrow;
      }
    } finally {
      await transaction?.finish(endTimestamp: endTimestamp);
    }
  }

  bool _isRouteIgnored(Route<dynamic> route) {
    return _ignoreRoutes.isNotEmpty &&
        _ignoreRoutes.contains(_getRouteName(route));
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
    DateTime? timestamp,
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
      timestamp: timestamp,
      data: data,
    );
  }

  RouteObserverBreadcrumb._({
    required String navigationType,
    String? from,
    dynamic fromArgs,
    String? to,
    dynamic toArgs,
    super.level,
    super.timestamp,
    Map<String, dynamic>? data,
  }) : super(
            category: _navigationKey,
            type: _navigationKey,
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
