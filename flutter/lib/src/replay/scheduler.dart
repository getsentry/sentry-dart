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
  final SchedulerCallback _callback;
  final Duration _interval;
  bool _running = false;
  Future<void>? _scheduled;

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
    final scheduled = _scheduled;
    _scheduled = null;
    if (scheduled != null) {
      await scheduled;
    }
  }

  @pragma('vm:prefer-inline')
  void _scheduleNext() {
    _scheduled ??= Future.delayed(_interval, _runAfterNextFrame);
  }

  @pragma('vm:prefer-inline')
  void _runAfterNextFrame() {
    _scheduled = null;
    _addPostFrameCallback(_run);
  }

  void _run(Duration sinceSchedulerEpoch) {
    if (!_running) return;
    _callback(sinceSchedulerEpoch).then((_) => _scheduleNext());
  }
}
