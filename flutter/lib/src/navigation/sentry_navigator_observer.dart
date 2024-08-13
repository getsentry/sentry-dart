// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import '../integrations/integrations.dart';
import '../native/native_frames.dart';
import '../native/sentry_native_binding.dart';
import 'time_to_display_tracker.dart';

import '../../sentry_flutter.dart';
import '../event_processor/flutter_enricher_event_processor.dart';

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
    @visibleForTesting TimeToDisplayTracker? timeToDisplayTracker,
    List<String>? ignoreRoutes,
  })  : _hub = hub ?? HubAdapter(),
        _enableAutoTransactions = enableAutoTransactions,
        _autoFinishAfter = autoFinishAfter,
        _setRouteNameAsTransaction = setRouteNameAsTransaction,
        _routeNameExtractor = routeNameExtractor,
        _additionalInfoProvider = additionalInfoProvider,
        _ignoreRoutes = ignoreRoutes ?? [],
        _native = SentryFlutter.native {
    _isCreated = true;
    if (enableAutoTransactions) {
      _hub.options.sdk.addIntegration('UINavigationTracing');
    }
    _timeToDisplayTracker =
        timeToDisplayTracker ?? _initializeTimeToDisplayTracker();
  }

  /// Initializes the TimeToDisplayTracker with the option to enable time to full display tracing.
  TimeToDisplayTracker _initializeTimeToDisplayTracker() {
    bool enableTimeToFullDisplayTracing = false;
    final options = _hub.options;
    if (options is SentryFlutterOptions) {
      enableTimeToFullDisplayTracing = options.enableTimeToFullDisplayTracing;
    }
    return TimeToDisplayTracker(
        enableTimeToFullDisplayTracing: enableTimeToFullDisplayTracing);
  }

  final Hub _hub;
  final bool _enableAutoTransactions;
  final Duration _autoFinishAfter;
  final bool _setRouteNameAsTransaction;
  final RouteNameExtractor? _routeNameExtractor;
  final AdditionalInfoExtractor? _additionalInfoProvider;
  final SentryNativeBinding? _native;
  final List<String> _ignoreRoutes;
  static TimeToDisplayTracker? _timeToDisplayTracker;

  @internal
  static TimeToDisplayTracker? get timeToDisplayTracker =>
      _timeToDisplayTracker;

  ISentrySpan? _transaction;

  static String? _currentRouteName;

  static bool _isCreated = false;

  @internal
  static bool get isCreated => _isCreated;

  @internal
  static String? get currentRouteName => _currentRouteName;

  Completer<void>? _completedDisplayTracking = Completer();

  // Since didPush does not have a future, we can keep track of when the display tracking has finished
  @visibleForTesting
  Completer<void>? get completedDisplayTracking => _completedDisplayTracking;

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

    // Clearing the display tracker here is safe since didPush happens before the Widget is built
    _timeToDisplayTracker?.clear();
    _finishTimeToDisplayTracking();
    _startTimeToDisplayTracking(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    if (newRoute != null && _isRouteIgnored(newRoute) ||
        oldRoute != null && _isRouteIgnored(oldRoute)) {
      return;
    }

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

    if (_isRouteIgnored(route) ||
        previousRoute != null && _isRouteIgnored(previousRoute)) {
      return;
    }

    _setCurrentRouteName(previousRoute);
    _setCurrentRouteNameAsTransaction(previousRoute);

    _addBreadcrumb(
      type: 'didPop',
      from: route.settings,
      to: previousRoute?.settings,
    );

    _finishTimeToDisplayTracking(clearAfter: true);
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

  Future<void> _startTransaction(
      Route<dynamic>? route, DateTime startTimestamp) async {
    String? name = _getRouteName(route);
    final arguments = route?.settings.arguments;

    if (name == null) {
      return;
    }

    if (name == '/') {
      name = rootScreenName;
    }
    final transactionContext = SentryTransactionContext(
      name,
      SentrySpanOperations.uiLoad,
      transactionNameSource: SentryTransactionNameSource.component,
      origin: SentryTraceOrigins.autoNavigationRouteObserver,
    );

    _transaction = _hub.startTransactionWithContext(
      transactionContext,
      startTimestamp: startTimestamp,
      waitForChildren: true,
      autoFinishAfter: _autoFinishAfter,
      trimEnd: true,
      onFinish: (transaction) async {
        _transaction = null;
        final nativeFrames =
            await _native?.endNativeFrames(transaction.context.traceId);
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

    await _native?.beginNativeFrames();
  }

  Future<void> _finishTimeToDisplayTracking({bool clearAfter = false}) async {
    final transaction = _transaction;
    _transaction = null;
    try {
      _hub.configureScope((scope) {
        if (scope.span == transaction) {
          scope.span = null;
        }
      });

      if (transaction == null || transaction.finished) {
        return;
      }

      // Cancel unfinished TTID/TTFD spans, e.g this might happen if the user navigates
      // away from the current route before TTFD or TTID is finished.
      for (final child in (transaction as SentryTracer).children) {
        final isTTIDSpan = child.context.operation ==
            SentrySpanOperations.uiTimeToInitialDisplay;
        final isTTFDSpan =
            child.context.operation == SentrySpanOperations.uiTimeToFullDisplay;
        if (!child.finished && (isTTIDSpan || isTTFDSpan)) {
          await child.finish(status: SpanStatus.deadlineExceeded());
        }
      }
    } catch (exception, stacktrace) {
      _hub.options.logger(
        SentryLevel.error,
        'Error while finishing time to display tracking',
        exception: exception,
        stackTrace: stacktrace,
      );
    } finally {
      await transaction?.finish();
      if (clearAfter) {
        _clear();
      }
    }
  }

  Future<void> _startTimeToDisplayTracking(Route<dynamic>? route) async {
    try {
      final routeName = _getRouteName(route) ?? _currentRouteName;
      if (!_enableAutoTransactions || routeName == null) {
        return;
      }

      bool isAppStart = routeName == '/';
      DateTime startTimestamp = _hub.options.clock();
      DateTime? endTimestamp;

      if (isAppStart) {
        final appStartInfo = await NativeAppStartIntegration.getAppStartInfo();
        if (appStartInfo == null) return;

        startTimestamp = appStartInfo.start;
        endTimestamp = appStartInfo.end;
      }

      await _startTransaction(route, startTimestamp);

      final transaction = _transaction;
      if (transaction == null) {
        return;
      }

      if (isAppStart && endTimestamp != null) {
        await _timeToDisplayTracker?.trackAppStartTTD(transaction,
            startTimestamp: startTimestamp, endTimestamp: endTimestamp);
      } else {
        await _timeToDisplayTracker?.trackRegularRouteTTD(transaction,
            startTimestamp: startTimestamp);
      }
    } catch (exception, stacktrace) {
      _hub.options.logger(
        SentryLevel.error,
        'Error while tracking time to display',
        exception: exception,
        stackTrace: stacktrace,
      );
    } finally {
      _clear();
    }
  }

  void _clear() {
    if (_completedDisplayTracking?.isCompleted == false) {
      _completedDisplayTracking?.complete();
    }
    _completedDisplayTracking = Completer();
    _timeToDisplayTracker?.clear();
  }

  @internal
  static const String rootScreenName = 'root /';

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
