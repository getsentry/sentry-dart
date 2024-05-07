import 'package:flutter/rendering.dart';
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
  bool _scheduled = false;

  final void Function(FrameCallback callback, {String debugLabel})
      _addPostFrameCallback;

  Scheduler(this._interval, this._callback)
      : _addPostFrameCallback = RendererBinding.instance.addPostFrameCallback;

  @visibleForTesting
  Scheduler.withCustomFrameTiming(
      this._interval, this._callback, this._addPostFrameCallback);

  void start() {
    _running = true;
    if (!_scheduled) {
      _runAfterNextFrame();
    }
  }

  void stop() {
    _running = false;
  }

  @pragma('vm:prefer-inline')
  void _scheduleNext() {
    if (!_scheduled) {
      _scheduled = true;
      Future.delayed(_interval, _runAfterNextFrame);
    }
  }

  @pragma('vm:prefer-inline')
  void _runAfterNextFrame() {
    _addPostFrameCallback(_run);
  }

  void _run(Duration sinceSchedulerEpoch) {
    _scheduled = false;
    if (!_running) return;
    _callback(sinceSchedulerEpoch).then((_) => _scheduleNext());
  }
}
