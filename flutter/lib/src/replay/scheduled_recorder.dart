import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../screenshot/screenshot.dart';
import 'replay_recorder.dart';
import 'scheduled_recorder_config.dart';
import 'scheduler.dart';

@internal
typedef ScheduledScreenshotRecorderCallback = Future<void> Function(
    Screenshot screenshot, bool isNewlyCaptured);

@internal
class ScheduledScreenshotRecorder extends ReplayScreenshotRecorder {
  late final ScheduledScreenshotRecorderCallback _callback;
  var _status = _Status.stopped;
  Scheduler? _scheduler;
  // late final _idleFrameFiller = _IdleFrameFiller(_frameDuration, _onScreenshot);

  @override
  @protected
  ScheduledScreenshotRecorderConfig get config =>
      super.config as ScheduledScreenshotRecorderConfig;

  ScheduledScreenshotRecorder(super.options,
      [ScheduledScreenshotRecorderCallback? callback]) {
    if (callback != null) {
      _callback = callback;
    }
  }

  void _addPostFrameCallback(FrameCallback callback) {
    options.bindingUtils.instance!
      ..ensureVisualUpdate()
      ..addPostFrameCallback(callback);
  }

  set callback(ScheduledScreenshotRecorderCallback callback) {
    _callback = callback;
  }

  Future<void> start() async {
    assert(() {
      // The following fails if callback hasn't been provided
      // in the constructor nor set with a setter.
      _callback;
      return true;
    }());

    options.log(SentryLevel.debug, "$logName: starting capture");
    _status = _Status.running;
    await _restartScheduler();
  }

  Future<void> onConfigurationChanged(
      ScheduledScreenshotRecorderConfig config) async {
    super.config = config;
    options.log(SentryLevel.debug,
        "$logName: onConfigurationChanged (${config.width}x${config.height} @ ${config.frameRate} Hz).");

    await _restartScheduler();
  }

  Future<void> _stopScheduler() {
    return _scheduler?.stop() ?? Future.value();
  }

  Future<void> _restartScheduler() async {
    await _stopScheduler();

    if (super.config == null) {
      return;
    }

    assert(config.frameRate > 0);
    var frameDuration = Duration(milliseconds: 1000 ~/ config.frameRate);
    assert(frameDuration.inMicroseconds > 0);

    _scheduler = Scheduler(
      frameDuration,
      (_) => capture(_onImageCaptured),
      _addPostFrameCallback,
    );

    if (_status == _Status.running) {
      _scheduler!.start();

      // We need to schedule a frame because if this happens in-between user
      // actions, there may not be any frame captured for a long time so even
      // the IdleFrameFiller won't have anything to repeat. This would appear
      // as if the replay was broken.
      options.bindingUtils.instance!.ensureVisualUpdate();
    }
  }

  Future<void> stop() async {
    options.log(SentryLevel.debug, "$logName: stopping capture.");
    _status = _Status.stopped;
    await _stopScheduler();
    // await Future.wait([_stopScheduler(), _idleFrameFiller.stop()]);
    options.log(SentryLevel.debug, "$logName: capture stopped.");
  }

  Future<void> pause() async {
    if (_status == _Status.running) {
      _status = _Status.paused;
      // _idleFrameFiller.pause();
      await _stopScheduler();
    }
  }

  Future<void> resume() async {
    if (_status == _Status.paused) {
      _status = _Status.running;
      await _restartScheduler();
      // _idleFrameFiller.resume();
    }
  }

  Future<void> _onImageCaptured(Screenshot screenshot) async {
    if (_status == _Status.running) {
      await _onScreenshot(screenshot, true);
      // _idleFrameFiller.actualFrameReceived(screenshot);
    } else {
      // drop any screenshots from callbacks if the replay has already been stopped/paused.
      options.log(SentryLevel.debug,
          '$logName: screenshot dropped because status=${_status.name}.');
    }
  }

  Future<void> _onScreenshot(
      Screenshot screenshot, bool isNewlyCaptured) async {
    if (_status == _Status.running) {
      await _callback(screenshot, isNewlyCaptured);
    } else {
      // drop any screenshots from callbacks if the replay has already been stopped/paused.
      options.log(SentryLevel.debug,
          '$logName: screenshot dropped because status=${_status.name}.');
    }
  }
}

// TODO this is currently unused because we've decided to capture on every
//      frame. Consider removing if we don't reverse the decision in the future.

// /// Workaround for https://github.com/getsentry/sentry-java/issues/3677
// /// In short: when there are no postFrameCallbacks issued by Flutter (because
// /// there are no animations or user interactions), the replay recorder will
// /// need to get screenshots at a fixed frame rate. This class is responsible for
// /// filling the gaps between actual frames with the most recent frame.
// class _IdleFrameFiller {
//   final Duration _interval;
//   final ScheduledScreenshotRecorderCallback _callback;
//   var _status = _Status.running;
//   Future<void>? _scheduled;
//   Screenshot? _mostRecent;

//   _IdleFrameFiller(this._interval, this._callback);

//   void actualFrameReceived(Screenshot screenshot) {
//     // We store the most recent frame but only repost it when the most recent
//     // one is the same instance (unchanged).
//     _mostRecent = screenshot;
//     // Also, the initial reposted frame will be delayed to allow actual frames
//     // to cancel the reposting.
//     repostLater(_interval * 1.5, screenshot);
//   }

//   Future<void> stop() async {
//     _status = _Status.stopped;
//     final scheduled = _scheduled;
//     _scheduled = null;
//     _mostRecent = null;
//     await scheduled;
//   }

//   void pause() {
//     if (_status == _Status.running) {
//       _status = _Status.paused;
//     }
//   }

//   void resume() {
//     if (_status == _Status.paused) {
//       _status = _Status.running;
//     }
//   }

//   void repostLater(Duration delay, Screenshot screenshot) {
//     _scheduled = Future.delayed(delay, () async {
//       if (_status == _Status.stopped) {
//         return;
//       }

//       // Only repost if the screenshot haven't changed.
//       if (screenshot == _mostRecent) {
//         if (_status == _Status.running) {
//           // We don't strictly need to await here but it helps to reduce load.
//           // If the callback takes a long time, we still wait between calls,
//           // based on the configured rate.
//           await _callback(screenshot, false);
//         }
//         // On subsequent frames, we stick to the actual frame rate.
//         repostLater(_interval, screenshot);
//       }
//     });
//   }
// }

enum _Status { stopped, running, paused }
