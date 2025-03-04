// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/replay/scheduled_recorder.dart';
import 'package:sentry_flutter/src/replay/scheduled_recorder_config.dart';

class AndroidReplayRecorder extends ScheduledScreenshotRecorder {
  static AndroidReplayRecorder Function(
          ScheduledScreenshotRecorderConfig, SentryFlutterOptions) factory =
      AndroidReplayRecorder.new;

  AndroidReplayRecorder(super.config, super.options);

  @override
  Future<void> start() async {
    super.start();
  }
}
