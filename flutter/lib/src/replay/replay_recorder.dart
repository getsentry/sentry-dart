import 'dart:async';
import 'dart:developer';

import 'package:meta/meta.dart';

import '../screenshot/recorder.dart';

var _instanceCounter = 0;

@internal
class ReplayScreenshotRecorder extends ScreenshotRecorder {
  ReplayScreenshotRecorder(super.config, super.options)
      : super(
            privacyOptions: options.privacy,
            logName: 'ReplayRecorder #${++_instanceCounter}');

  @override
  @protected
  Future<void> executeTask(Future<void> Function() task, Flow flow) {
    // Future() schedules the task to be executed asynchronously with Timer.run.
    return Future(task);
  }
}
