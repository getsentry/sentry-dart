import 'package:flutter/scheduler.dart';
import 'package:sentry_flutter/src/frame_callback_handler.dart';

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

  // Should lead to 2 slow and 1 frozen frame
  final frameDurations = [
    Duration(milliseconds: 10),
    Duration(milliseconds: 20),
    Duration(milliseconds: 40),
    Duration(milliseconds: 710),
  ];

  @override
  void addPersistentFrameCallback(FrameCallback callback) async {
    // In tests the first frame will duration is always 0 because it's less accurate
    callback(Duration.zero);

    for (final duration in frameDurations) {
      await Future<void>.delayed(duration);
      callback(Duration.zero);
    }
  }

  @override
  bool hasScheduledFrame = true;

  @override
  Future<void> get endOfFrame => Future<void>.delayed(Duration.zero);
}
