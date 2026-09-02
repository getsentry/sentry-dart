import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';

@internal
typedef SchedulerCallback = Future<void> Function(Duration);

/// This is a low-priority scheduler.
/// We're not using Timer.periodic() because it may schedule a callback
/// even if the previous call hasn't finished (or started) yet.
/// Instead, we manually schedule a callback with a given delay after the
/// previous callback finished. Therefore, if the capture takes too long, we
/// won't overload the system. We sacrifice the frame rate for performance.
@internal
class Scheduler {
  // Bounds how long stop() waits for an in-flight callback so a stalled
  // capture (e.g. a wedged toImage()) can't hang teardown indefinitely.
  static const _stopTimeout = Duration(seconds: 2);

  final SchedulerCallback _callback;
  final Duration _interval;
  bool _running = false;
  Future<void>? _scheduled;
  Future<void>? _runningCallback;
  // Bumped by stop() to invalidate whenComplete() listeners registered by
  // _runAfterNextFrame() on a still-in-flight callback future. Futures can't
  // be un-listened, so a stalled callback that finally completes after
  // stop() has already moved on (timed out, or a restart is underway) would
  // otherwise still fire its stale listener and re-schedule _run().
  int _generation = 0;

  final void Function(FrameCallback callback) _addPostFrameCallback;

  Scheduler(this._interval, this._callback, this._addPostFrameCallback);

  void start() {
    _running = true;
    if (_scheduled == null) {
      _runAfterNextFrame();
    }
  }

  Future<void> stop() async {
    _running = false;
    _generation++;
    final scheduled = _scheduled;
    _scheduled = null;
    if (scheduled != null) {
      await scheduled;
    }
    // The scheduled future above only tracks the delay timer between runs,
    // not the callback itself, so we also need to await any run that's
    // currently in flight to make sure its GPU resources are released
    // before the caller (e.g. the app lifecycle teardown) proceeds. If it
    // times out, drop the reference too: a stalled callback's future never
    // completes, and leaving it in place would make _runAfterNextFrame()
    // wait on it forever on the next start(), permanently stalling capture.
    await _runningCallback?.timeout(_stopTimeout, onTimeout: () {});
    _runningCallback = null;
  }

  @pragma('vm:prefer-inline')
  void _scheduleNext() {
    if (_running) {
      _scheduled ??= Future.delayed(_interval, _runAfterNextFrame);
    }
  }

  @pragma('vm:prefer-inline')
  void _runAfterNextFrame() {
    final generation = _generation;
    final runningCallback = _runningCallback ?? Future.value();
    runningCallback.whenComplete(() {
      // A stop() happened since this listener was registered: the callback
      // future it was watching is abandoned, so don't act on it.
      if (generation != _generation) return;
      _scheduled = null;
      _addPostFrameCallback(_run);
    });
  }

  void _run(Duration sinceSchedulerEpoch) {
    if (!_running) return;
    _runningCallback = _callback(sinceSchedulerEpoch);
    _scheduleNext();
  }
}
