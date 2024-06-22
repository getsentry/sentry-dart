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
  Future<void> addPersistentFrameCallback(FrameCallback callback) async {
    for (final duration in fakeFrameDurations) {
      // Let's wait a bit so the timestamp intervals are large enough
      await Future<void>.delayed(Duration(milliseconds: 20));
      callback(duration);
    }
  }

  @override
  bool hasScheduledFrame = true;

  @override
  Future<void> get endOfFrame => Future<void>.value();
}
