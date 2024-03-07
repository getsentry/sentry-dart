import 'package:flutter/scheduler.dart';
import 'package:sentry_flutter/src/frame_callback_handler.dart';

class FakeFrameCallbackHandler implements FrameCallbackHandler {
  FrameCallback? storedCallback;

  final Duration finishAfterDuration;

  FakeFrameCallbackHandler(
      {this.finishAfterDuration = const Duration(milliseconds: 50)});

  @override
  void addPostFrameCallback(FrameCallback callback) async {
    // ignore: inference_failure_on_instance_creation
    await Future.delayed(finishAfterDuration);
    callback(Duration.zero);
  }
}
