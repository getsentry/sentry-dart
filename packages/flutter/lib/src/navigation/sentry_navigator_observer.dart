// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
// ignore: implementation_imports
import 'package:sentry/src/telemetry/span/transaction/sentry_tracer.dart';
// ignore: implementation_imports
import 'package:sentry/src/utils/iterable_utils.dart';

import '../../sentry_flutter.dart';
import '../enrichment/flutter_enricher_event_processor.dart';
import '../sessions/web_session_integration.dart';
import '../utils/internal_logger.dart';
import '../sessions/web_session_handler.dart';
import 'time_to_display_tracker.dart';
import 'time_to_display_tracker_v2.dart';

/// This key must be used so that the web interface displays the events nicely
/// See https://develop.sentry.dev/sdk/event-payloads/breadcrumbs/
const _navigationKey = 'navigation';

typedef RouteNameExtractor = RouteSettings? Function(RouteSettings? settings);

typedef AdditionalInfoExtractor =
    Map<String, dynamic>? Function(RouteSettings? from, RouteSettings? to);

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
/// If [enableNewTraceOnNavigation] is true, a fresh trace is generated
/// before each push, pop, or replace event. Disabled by default.
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
    this._enableNewTraceOnNavigation = false,
    this._autoFinishAfter = const Duration(seconds: 3),
    this._setRouteNameAsTransaction = false,
    this._routeNameExtractor,
    this._additionalInfoProvider,
    List<String>? ignoreRoutes,
  }) : _hub = hub ?? HubAdapter(),
       _enableAutoTransactions = enableAutoTransactions,
       _ignoreRoutes = ignoreRoutes ?? [] {
    _isCreated = true;
    if (enableAutoTransactions) {
      _hub.options.sdk.addIntegration('UINavigationTracing');
    }
    _timeToDisplayTracker = _initializeTimeToDisplayTracker();
    _timeToDisplayTrackerV2 = _initializeTimeToDisplayTrackerV2();
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

  TimeToDisplayTrackerV2? _initializeTimeToDisplayTrackerV2() {
    final options = _hub.options;
    if (options is SentryFlutterOptions) {
      return options.timeToDisplayTrackerV2;
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
  TimeToDisplayTrackerV2? _timeToDisplayTrackerV2;

  WebSessionHandler? _webSessionHandler;

  @visibleForTesting
  WebSessionHandler? get webSessionHandler => _webSessionHandler;

  ISentrySpan? _transaction;

  /// The route whose display the pending app start measures, if any.
  Route<dynamic>? _appStartRoute;

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
    if (previousRoute == null && _nameAppStartRoute(routeName)) {
      _appStartRoute = route;
      return;
    }

    if (routeName != null && routeName != '/') {
      // A new display takes over from the app start. Routes that start none
      // (dialogs, unnamed routes) keep the handoff for a later replacement.
      _appStartRoute = null;

      // Don't generate a new trace on initial app start / root
      // During SentryFlutter.init a traceId is already created
      _startNewTraceIfEnabled();

      // App start TTID/TTFD is taken care of by app start integrations
      _trackRouteDisplay(routeName, arguments: route.settings.arguments);
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

    // Navigator.replace can also replace a route below the current one, which
    // leaves the displayed screen, and so its display tracking, unchanged.
    if (newRoute == null || !newRoute.isCurrent) {
      return;
    }
    final routeName = _getRouteName(newRoute);

    // Replacing the route that named the app start before its first-frame
    // timing arrives (e.g. a splash screen) means the replacement is what the
    // app start ends up displaying, so it takes over that reservation instead
    // of starting a competing route transaction.
    if (oldRoute != null && oldRoute == _appStartRoute) {
      final renamed = _nameAppStartRoute(routeName, requirePending: false);
      _appStartRoute = renamed ? newRoute : null;
      if (renamed) return;
    }

    if (routeName != null && routeName != '/') {
      _appStartRoute = null;
      _trackRouteDisplay(routeName, arguments: newRoute.settings.arguments);
    }
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

    if (_hub.options.traceLifecycle == SentryTraceLifecycle.stream) {
      _timeToDisplayTrackerV2?.cancelCurrentRoute();
    } else {
      final timestamp = _hub.options.clock();
      _finishTransaction(endTimestamp: timestamp);
    }
  }

  /// Hands the initial route's name to a pending app start, if there is one.
  ///
  /// The app-start integrations reserve the initial route's display spans
  /// before the first frame, so the observer must neither drop that
  /// reservation nor start a competing route transaction. Only the tracker
  /// belonging to the active trace lifecycle ever reports a pending app start.
  ///
  /// With [requirePending], only the first route may name the app start, so a
  /// later initial push (a nested navigator, for instance) is still treated as
  /// ordinary navigation. Without it, the reserved spans are renamed as long as
  /// they haven't started yet.
  ///
  /// Returns whether app start consumed the route change.
  bool _nameAppStartRoute(String? routeName, {bool requirePending = true}) {
    final tracker = _timeToDisplayTracker;
    if (tracker != null &&
        (!requirePending || tracker.isAppStartRoutePending) &&
        tracker.setAppStartRouteName(routeName)) {
      return true;
    }
    final trackerV2 = _timeToDisplayTrackerV2;
    return trackerV2 != null &&
        (!requirePending || trackerV2.isAppStartRoutePending) &&
        trackerV2.setAppStartRouteName(routeName);
  }

  void _startNewTraceIfEnabled() {
    if (_enableNewTraceOnNavigation) {
      _hub.generateNewTrace();
    }
  }

  void _trackRouteDisplay(String routeName, {Object? arguments}) {
    final isStreaming =
        _hub.options.traceLifecycle == SentryTraceLifecycle.stream;
    final timestamp = _hub.options.clock();

    // A route display ends the previous one, the app start included, whether
    // or not auto transactions start a new one. Routes that start no display
    // of their own (unnamed ones, dialogs) leave it running, the same as they
    // do for any other route.
    if (isStreaming) {
      // Only the app start: trackRoute ends the current route span below, and
      // other idle spans (user interactions) aren't displays.
      _timeToDisplayTrackerV2?.cancelAppStart();
    } else {
      // The app-start root has to hand the scope over, or spans from this
      // route keep parenting to it until its TTFD times out.
      unawaited(_timeToDisplayTracker?.releaseInitialDisplay());

      // Drops any app-start reservation that is still waiting for first-frame
      // timing. The route that named it was already handed to the app start
      // in didPush or didReplace, so only navigation away from it gets here.
      _timeToDisplayTracker?.clear();

      _finishTransaction(endTimestamp: timestamp);
    }

    if (!_enableAutoTransactions) {
      internalLogger.info(
        'SentryNavigatorObserver: auto transactions disabled, skipping time-to-display instrumentation.',
      );
      return;
    }

    if (isStreaming) {
      _timeToDisplayTrackerV2?.trackRoute(routeName);
    } else {
      final transactionContext = _createTransactionContext(routeName);
      _startTransaction(timestamp, transactionContext, arguments);
    }
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
    _hub.addBreadcrumb(
      RouteObserverBreadcrumb(
        navigationType: type,
        from: _routeNameExtractor?.call(from) ?? from,
        to: _routeNameExtractor?.call(to) ?? to,
        timestamp: _hub.options.clock(),
        data: _additionalInfoProvider?.call(from, to),
      ),
    );
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
        // The next route may already be active when this transaction finishes.
        if (_transaction == transaction) {
          _transaction = null;
        }
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
      internalLogger.error(
        'SentryNavigatorObserver: error while finishing transaction',
        error: exception,
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
           'from': ?from,
           'from_arguments': ?fromArgs,
           'to': ?to,
           'to_arguments': ?toArgs,
           'data': ?data,
         },
       );

  static dynamic _formatArgs(Object? args) {
    if (args == null) {
      return null;
    }
    if (args is Map<String, dynamic>) {
      return args.map<String, dynamic>(
        (key, dynamic value) => MapEntry<String, String>(key, value.toString()),
      );
    }
    return args.toString();
  }
}
