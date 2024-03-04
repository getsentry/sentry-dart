import 'package:flutter/scheduler.dart';
import 'package:sentry_flutter/src/frame_callback_handler.dart';

class FakeFrameCallbackHandler implements FrameCallbackHandler {
  FrameCallback? storedCallback;

  final Duration _finishAfterDuration;

  FakeFrameCallbackHandler(
      {Duration finishAfterDuration = const Duration(milliseconds: 500)})
      : _finishAfterDuration = finishAfterDuration;

  @override
  void addPostFrameCallback(FrameCallback callback) async {
    // ignore: inference_failure_on_instance_creation
    await Future.delayed(_finishAfterDuration);
    callback(Duration.zero);
  }
}
