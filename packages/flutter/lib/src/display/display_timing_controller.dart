import 'display_handles.dart';
import 'display_transaction_engine.dart';
import 'display_txn.dart';

/// Display timing controller facade for TTID/TTFD V2.
class DisplayTimingController {
  DisplayTimingController({required DisplayTransactionEngine engine})
      : _engine = engine;

  final DisplayTransactionEngine _engine;

  // Track current tokens per slot to support invalidation.
  Object? _rootToken;
  Object? _routeToken;

  AppStartDisplayHandle startApp(
      {required String name, required DateTime now}) {
    // Enforce single active state globally: abort any active slot and
    // invalidate existing tokens/handles before starting root.
    _abortAllAndInvalidate(when: now);

    final token = Object();
    _rootToken = token;
    _engine.start(slot: DisplaySlot.root, name: name, now: now);
    return AppStartDisplayHandle(this, token);
  }

  RouteDisplayHandle startRoute({
    required String name,
    Object? arguments,
    required DateTime now,
    Duration? autoFinishAfter,
  }) {
    // Enforce single active state globally: abort any active slot and
    // invalidate existing tokens/handles before starting route.
    _abortAllAndInvalidate(when: now);

    final token = Object();
    _routeToken = token;
    _engine.start(
      slot: DisplaySlot.route,
      name: name,
      arguments: arguments,
      now: now,
      autoFinishAfter: autoFinishAfter,
    );
    return RouteDisplayHandle(this, token);
  }

  void finishTtid({
    required DisplaySlot slot,
    required Object token,
    required DateTime when,
  }) {
    if (!_isTokenCurrent(slot, token)) return;
    _engine.finishTtid(slot: slot, when: when);
  }

  void finishTtfd({
    required DisplaySlot slot,
    required Object token,
    required DateTime when,
  }) {
    if (!_isTokenCurrent(slot, token)) return;
    _engine.finishTtfd(slot: slot, when: when);
  }

  void abortCurrent({required DisplaySlot slot, required DateTime when}) {
    _engine.abort(slot: slot, when: when);
    _invalidate(slot);
  }

  // Abort any active transaction in both slots and invalidate their tokens.
  void _abortAllAndInvalidate({required DateTime when}) {
    // Abort route then root (order not important, but deterministic).
    _engine.abort(slot: DisplaySlot.route, when: when);
    _engine.abort(slot: DisplaySlot.root, when: when);
    _invalidate(DisplaySlot.route);
    _invalidate(DisplaySlot.root);
  }

  void _invalidate(DisplaySlot slot) {
    switch (slot) {
      case DisplaySlot.root:
        _rootToken = null;
        break;
      case DisplaySlot.route:
        _routeToken = null;
        break;
    }
  }

  bool _isTokenCurrent(DisplaySlot slot, Object token) {
    final current = switch (slot) {
      DisplaySlot.root => _rootToken,
      DisplaySlot.route => _routeToken,
    };
    return identical(current, token);
  }

  // Public facade to get current handle for a given slot.
  DisplayHandle? currentDisplay(DisplaySlot slot) {
    final token = switch (slot) {
      DisplaySlot.root => _rootToken,
      DisplaySlot.route => _routeToken,
    };
    if (token == null) return null;
    return slot == DisplaySlot.root
        ? AppStartDisplayHandle(this, token)
        : RouteDisplayHandle(this, token);
  }

  // Visible for tests: expose engine snapshot for assertions.
  ({DisplayState root, DisplayState route}) snapshot() => _engine.snapshot();
}
