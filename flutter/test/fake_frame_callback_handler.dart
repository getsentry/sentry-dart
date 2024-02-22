import 'package:flutter/scheduler.dart';
import 'package:sentry_flutter/src/frame_callback_handler.dart';

class FakeFrameCallbackHandler implements IFrameCallbackHandler {
  FrameCallback? storedCallback;

  final Duration _finishAfterDuration;

  FakeFrameCallbackHandler(
      {Duration finishAfterDuration = const Duration(milliseconds: 500)})
      : _finishAfterDuration = finishAfterDuration;

  @override
  void addPostFrameCallback(FrameCallback callback,
      {String debugLabel = 'callback'}) async {
    await Future.delayed(_finishAfterDuration);
    callback(Duration.zero);
  }
}
