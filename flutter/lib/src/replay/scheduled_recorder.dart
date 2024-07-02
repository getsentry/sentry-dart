import 'dart:async';
import 'dart:ui';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'recorder.dart';
import 'scheduler.dart';

@internal
typedef ScreenshotRecorderCallback = Future<void> Function(Image);

@internal
class ScheduledScreenshotRecorder extends ScreenshotRecorder {
  late final Scheduler _scheduler;
  final ScreenshotRecorderCallback _callback;

  ScheduledScreenshotRecorder(super.config, this._callback, super.options) {
    final frameDuration = Duration(milliseconds: 1000 ~/ config.frameRate);
    _scheduler = Scheduler(frameDuration, _capture,
        options.bindingUtils.instance!.addPostFrameCallback);
  }

  void start() {
    options.logger(SentryLevel.debug, "Replay: starting replay capture.");
    _scheduler.start();
  }

  Future<void> stop() async {
    await _scheduler.stop();
    options.logger(SentryLevel.debug, "Replay: replay capture stopped.");
  }

  Future<void> _capture(Duration sinceSchedulerEpoch) async =>
      capture(_callback);
}
