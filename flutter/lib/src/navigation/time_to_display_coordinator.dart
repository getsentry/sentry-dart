import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../integrations/native_app_start_handler.dart';
import 'time_to_display_manager.dart';

class TimeToDisplayCoordinator {
  TimeToDisplayCoordinator(this._hub, {TimeToDisplayManager? manager})
      : _manager = manager ?? TimeToDisplayManager(_hub);

  // ───────────────────────────  Fields  ────────────────────────────────────
  final Hub _hub;
  final TimeToDisplayManager _manager;

  AppStartTimingHandle? _appStartTimingHandle;

  AppStartTimingHandle? get appStartTimingHandle => _appStartTimingHandle;

  RouteTimingHandle? _routeTimingHandle;

  RouteTimingHandle? get routeTimingHandle => _routeTimingHandle;

  /// Called by your bootstrap
  AppStartTimingHandle? startApp({
    required DateTime ts,
    required bool coldStart,
    required SpanId spanId,
  }) {
    abortTransaction(ts: ts);
    print('start: ${ts.millisecondsSinceEpoch}');
    _manager.startTransaction(
        routeName: 'root /', ts: ts, spanId: spanId, isRootScreen: true);
    final handle = AppStartTimingHandle(spanId, this);
    _appStartTimingHandle = handle;
    return handle;
  }

  /// Called by your navigator observer
  RouteTimingHandle? startRoute({
    required String routeName,
    required DateTime ts,
    required SpanId spanId,
  }) {
    abortTransaction(ts: ts);
    _manager.startTransaction(
        routeName: routeName, ts: ts, spanId: spanId, isRootScreen: false);
    final handle = RouteTimingHandle(spanId, this);
    _routeTimingHandle = handle;
    return handle;
  }

  void endTtid(SpanId id, DateTime ts, bool isRootScreen) {
    _manager.finishTtid(id: id, ts: ts, isRootScreen: isRootScreen);
  }

  void abortTransaction({required DateTime ts}) {
    _manager.abortTransaction(ts: ts);
  }
}

/// Only for the root app‑start transaction.
@immutable
final class AppStartTimingHandle {
  const AppStartTimingHandle(this._spanId, this._interactor);

  final SpanId _spanId;
  final TimeToDisplayCoordinator _interactor;

  void endTtid(DateTime ts) => _interactor.endTtid(_spanId, ts, true);

// void reportFullyDisplayed(DateTime ts) =>
//     _interactor.dispatch(FullDisplayReported(spanId: _spanId, ts: ts));
}

/// For normal route‑push transactions.
@immutable
final class RouteTimingHandle {
  const RouteTimingHandle(this._spanId, this._interactor);
// maybe add the txn
  final SpanId _spanId;
  final TimeToDisplayCoordinator _interactor;

  void endTtid(DateTime ts) => _interactor.endTtid(_spanId, ts, false);

// void reportFullyDisplayed(DateTime ts) =>
//     _interactor._dispatch(FullDisplayReported(spanId: _spanId, ts: ts));
}
