// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/replay/scheduled_recorder.dart';

class AndroidReplayRecorder extends ScheduledScreenshotRecorder {
  static AndroidReplayRecorder Function(SentryFlutterOptions) factory =
      AndroidReplayRecorder.new;

  AndroidReplayRecorder(super.options);

  @override
  Future<void> start() async {
    await super.start();
  }
}
