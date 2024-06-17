import 'package:flutter/scheduler.dart';
import 'package:sentry_flutter/src/frame_callback_handler.dart';

import 'mocks.dart';

class FakeFrameCallbackHandler implements FrameCallbackHandler {
  final Duration finishAfterDuration;

  FakeFrameCallbackHandler(
      {this.finishAfterDuration = const Duration(milliseconds: 50)});

  @override
  void addPostFrameCallback(FrameCallback callback) async {
    // ignore: inference_failure_on_instance_creation
    await Future.delayed(finishAfterDuration);
    callback(Duration.zero);
  }

  @override
  void addPersistentFrameCallback(FrameCallback callback) async {
    // In tests, the duration of the first frame is always reported as 0.
    // This is because the first frame of the callback is generally less accurate
    // compared to the subsequent frames. Since we cannot track the time since the
    // previous frame (for the initial frame), we cannot determine the full duration of it.
    for (final duration in fakeFrameDurations) {
      await Future<void>.delayed(duration);
      callback(Duration.zero);
    }
  }

  @override
  bool hasScheduledFrame = true;

  @override
  Future<void> get endOfFrame => Future<void>.value();
}
