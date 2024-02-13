import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../event_processor/flutter_enricher_event_processor.dart';
import '../integrations/integrations.dart';
import '../native/sentry_native.dart';
import 'display_strategy_evaluator.dart';

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
    Duration autoFinishAfter = const Duration(seconds: 3),
    bool setRouteNameAsTransaction = false,
    RouteNameExtractor? routeNameExtractor,
    AdditionalInfoExtractor? additionalInfoProvider,
  })  : _hub = hub ?? HubAdapter(),
        _enableAutoTransactions = enableAutoTransactions,
        _autoFinishAfter = autoFinishAfter,
        _setRouteNameAsTransaction = setRouteNameAsTransaction,
        _routeNameExtractor = routeNameExtractor,
        _additionalInfoProvider = additionalInfoProvider,
        _native = SentryFlutter.native {
    if (enableAutoTransactions) {
      // ignore: invalid_use_of_internal_member
      _hub.options.sdk.addIntegration('UINavigationTracing');
    }
  }

  final Hub _hub;
  final bool _enableAutoTransactions;
  final Duration _autoFinishAfter;
  final bool _setRouteNameAsTransaction;
  final RouteNameExtractor? _routeNameExtractor;
  final AdditionalInfoExtractor? _additionalInfoProvider;
  final SentryNative? _native;

  ISentrySpan? _transaction;
  static DateTime? _startTimestamp;
  static ISentrySpan? _ttidSpan;
  static ISentrySpan? _ttfdSpan;

  static String? _currentRouteName;

  @internal
  static String? get currentRouteName => _currentRouteName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    _setCurrentRouteName(route);
    _setCurrentRouteNameAsTransaction(route);

    _addBreadcrumb(
      type: 'didPush',
      from: previousRoute?.settings,
      to: route.settings,
    );

    _finishTransaction();
    _startMeasurement(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    _setCurrentRouteName(newRoute);
    _setCurrentRouteNameAsTransaction(newRoute);

    _addBreadcrumb(
      type: 'didReplace',
      from: oldRoute?.settings,
      to: newRoute?.settings,
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    _setCurrentRouteName(previousRoute);
    _setCurrentRouteNameAsTransaction(previousRoute);

    _addBreadcrumb(
      type: 'didPop',
      from: route.settings,
      to: previousRoute?.settings,
    );

    _finishTransaction();
    _startMeasurement(previousRoute);
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
      // ignore: invalid_use_of_internal_member
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

  Future<void> _startTransaction(Route<dynamic>? route,
      {DateTime? startTimestamp}) async {
    if (!_enableAutoTransactions) {
      return;
    }

    String? name = _getRouteName(route);
    final arguments = route?.settings.arguments;

    if (name == null) {
      return;
    }

    if (name == '/') {
      name = 'root ("/")';
    }

    final transactionContext = SentryTransactionContext(
      name,
      'navigation',
      transactionNameSource: SentryTransactionNameSource.component,
      // ignore: invalid_use_of_internal_member
      origin: SentryTraceOrigins.autoNavigationRouteObserver,
    );

    _transaction = _hub.startTransactionWithContext(
      transactionContext,
      waitForChildren: true,
      autoFinishAfter: _autoFinishAfter,
      trimEnd: true,
      startTimestamp: startTimestamp,
      onFinish: (transaction) async {
        final nativeFrames = await _native
            ?.endNativeFramesCollection(transaction.context.traceId);
        if (nativeFrames != null) {
          final measurements = nativeFrames.toMeasurements();
          for (final item in measurements.entries) {
            final measurement = item.value;
            transaction.setMeasurement(
              item.key,
              measurement.value,
              unit: measurement.unit,
            );
          }
        }
      },
    );

    // if _enableAutoTransactions is enabled but there's no traces sample rate
    if (_transaction is NoOpSentrySpan) {
      _transaction = null;
      return;
    }

    if (arguments != null) {
      _transaction?.setData('route_settings_arguments', arguments);
    }

    await _hub.configureScope((scope) {
      scope.span ??= _transaction;
    });

    await _native?.beginNativeFramesCollection();
  }

  Future<void> _finishTransaction() async {
    _transaction?.status ??= SpanStatus.ok();
    await _transaction?.finish();
  }

  void _startMeasurement(Route<dynamic>? route) async {
    // Assigning a timestamp within this function so we don't have to force unwrap _startTimestamp
    final startTimestamp = DateTime.now();
    _startTimestamp = startTimestamp;

    final routeName = _getRouteName(route);
    final isRootScreen = routeName == '/';
    final didFetchAppStart = _native?.didFetchAppStart;
    if (isRootScreen && didFetchAppStart == false) {
      // This branch is a special edge case that only happens once
      AppStartTracker().onAppStartComplete((appStartInfo) async {
        // Create a transaction based on app start start time
        // Then create ttidSpan and finish immediately with the app start start & end time
        // This is a small workaround to pass the correct time stamps since we cannot mutate
        // timestamps of transactions or spans in history
        if (appStartInfo != null && routeName != null) {
          await _startTransaction(route, startTimestamp: appStartInfo.start);
          final ttidSpan =
              _createTTIDSpan(_transaction!, routeName, appStartInfo.start);
          _finishSpan(ttidSpan, _transaction!, appStartInfo.end,
              measurement: appStartInfo.measurement);
        }
      });
    } else {
      await _startTransaction(route, startTimestamp: startTimestamp);
      _initializeSpans(_transaction!, routeName!, startTimestamp);
      final endTimestamp = await _determineEndTime(routeName);
      final duration = endTimestamp.difference(startTimestamp).inMilliseconds;
      final measurement = SentryMeasurement('time_to_initial_display', duration,
          unit: DurationSentryMeasurementUnit.milliSecond);
      _finishSpan(_ttidSpan!, _transaction!, endTimestamp,
          measurement: measurement);
    }
  }

  Future<DateTime> _determineEndTime(String routeName) async {
    DateTime? endTimestamp;
    final endTimeCompleter = Completer<DateTime>();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      endTimestamp = DateTime.now();
      endTimeCompleter.complete(endTimestamp);
    });

    final strategyDecision =
        await DisplayStrategyEvaluator().decideStrategy(routeName);

    if (strategyDecision == StrategyDecision.manual &&
        !endTimeCompleter.isCompleted) {
      endTimestamp = DateTime.now();
      endTimeCompleter.complete(endTimestamp);
    } else if (!endTimeCompleter.isCompleted) {
      await endTimeCompleter.future;
    }

    return endTimestamp!;
  }

  void reportInitiallyDisplayed(String routeName) {
    DisplayStrategyEvaluator().reportManual(routeName);
  }

  void reportFullyDisplayed() {
    final endTimestamp = DateTime.now();
    final duration = endTimestamp.difference(_startTimestamp!).inMilliseconds;
    final transaction = Sentry.getSpan();
    if (_ttfdSpan == null || transaction == null) {
      return;
    }
    final measurement = SentryMeasurement('time_to_full_display', duration,
        unit: DurationSentryMeasurementUnit.milliSecond);
    _finishSpan(_ttfdSpan!, transaction, endTimestamp,
        measurement: measurement);
  }

  void _initializeSpans(
      ISentrySpan? transaction, String routeName, DateTime startTimestamp) {
    final options = _hub.options is SentryFlutterOptions
        // ignore: invalid_use_of_internal_member
        ? _hub.options as SentryFlutterOptions
        : null;
    if (transaction == null) return;
    _ttidSpan = _createTTIDSpan(transaction, routeName, startTimestamp);
    if (options?.enableTimeToFullDisplayTracing == true) {
      _ttfdSpan = _createTTFDSpan(transaction, routeName, startTimestamp);
    }
  }

  ISentrySpan _createTTIDSpan(
      ISentrySpan transaction, String routeName, DateTime startTimestamp) {
    return transaction.startChild(
      SentryTraceOrigins.uiTimeToInitialDisplay,
      description: '$routeName initial display',
      startTimestamp: startTimestamp,
    );
  }

  ISentrySpan _createTTFDSpan(
      ISentrySpan transaction, String routeName, DateTime startTimestamp) {
    return transaction.startChild(
      SentryTraceOrigins.uiTimeToFullDisplay,
      description: '$routeName full display',
      startTimestamp: startTimestamp,
    );
  }

  void _finishSpan(
      ISentrySpan span, ISentrySpan transaction, DateTime endTimestamp,
      {SentryMeasurement? measurement}) {
    if (measurement != null) {
      transaction.setMeasurement(measurement.name, measurement.value,
          unit: measurement.unit);
    }
    span.finish(endTimestamp: endTimestamp);
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

extension NativeFramesMeasurement on NativeFrames {
  Map<String, SentryMeasurement> toMeasurements() {
    final total = SentryMeasurement.totalFrames(totalFrames);
    final slow = SentryMeasurement.slowFrames(slowFrames);
    final frozen = SentryMeasurement.frozenFrames(frozenFrames);
    return {
      total.name: total,
      slow.name: slow,
      frozen.name: frozen,
    };
  }
}
