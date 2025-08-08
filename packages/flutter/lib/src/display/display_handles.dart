import 'display_txn.dart';
import 'display_timing_controller.dart';

/// A minimal interface for display handles.
abstract class DisplayHandle {
  void endTtid(DateTime now);
  void reportFullyDisplayed(DateTime now);
  void invalidate();
}

/// Internal base class implementing shared handle behavior.
class _BaseDisplayHandle implements DisplayHandle {
  _BaseDisplayHandle(this._controller, this._slot, this._token);

  final DisplayTimingController _controller;
  final DisplaySlot _slot;
  final Object _token; // identifies the underlying transaction/span

  bool _invalidated = false;
  bool _ttidEnded = false;
  bool _ttfdReported = false;

  /// Marks this handle as invalid. Subsequent calls will be no-ops.
  @override
  void invalidate() {
    _invalidated = true;
  }

  @override
  void endTtid(DateTime now) {
    if (_invalidated || _ttidEnded) return;
    _ttidEnded = true;
    _controller.finishTtid(slot: _slot, token: _token, when: now);
  }

  @override
  void reportFullyDisplayed(DateTime now) {
    if (_invalidated || _ttfdReported) return;
    _ttfdReported = true;
    _controller.finishTtfd(slot: _slot, token: _token, when: now);
  }
}

/// Opaque handle for app-start display timing.
class AppStartDisplayHandle extends _BaseDisplayHandle {
  AppStartDisplayHandle(
    DisplayTimingController controller,
    Object token,
  ) : super(controller, DisplaySlot.root, token);
}

/// Opaque handle for route display timing.
class RouteDisplayHandle extends _BaseDisplayHandle {
  RouteDisplayHandle(
    DisplayTimingController controller,
    Object token,
  ) : super(controller, DisplaySlot.route, token);
}
