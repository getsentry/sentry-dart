import 'package:flutter/scheduler.dart';
import 'package:sentry_flutter/src/frame_callback_handler.dart';

import 'mocks.dart';

class MockFrameCallbackHandler implements FrameCallbackHandler {
  FrameCallback? postFrameCallback;
  FrameCallback? persistentFrameCallback;

  @override
  void addPostFrameCallback(FrameCallback callback) {
    this.postFrameCallback = callback;
  }

  @override
  void addPersistentFrameCallback(FrameCallback callback) {
    this.persistentFrameCallback = persistentFrameCallback;
  }

  @override
  bool hasScheduledFrame = true;

  @override
  Future<void> get endOfFrame => Future<void>.value();
}
