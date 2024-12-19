import 'dart:async';
import 'dart:developer';

import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';

import '../screenshot/recorder.dart';

var _instanceCounter = 0;

@internal
class ReplayScreenshotRecorder extends ScreenshotRecorder {
  ReplayScreenshotRecorder(super.config, super.options)
      : super(
            privacyOptions: options.experimental.privacyForReplay,
            logName: 'ReplayRecorder #${++_instanceCounter}');

  @override
  @protected
  Future<void> executeTask(void Function() task, Flow flow) {
    // Schedule the task to run between frames, when the app is idle.
    return options.bindingUtils.instance
            ?.scheduleTask<void>(task, Priority.idle, flow: flow) ??
        Future.sync(task);
  }
}
