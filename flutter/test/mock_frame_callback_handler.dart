import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:sentry_flutter/src/frame_callback_handler.dart';

class MockFrameCallbackHandler implements FrameCallbackHandler {
  FrameCallback? postFrameCallback;
  FrameCallback? persistentFrameCallback;

  @override
  void addPostFrameCallback(FrameCallback callback) {
    postFrameCallback = callback;
  }

  @override
  void addPersistentFrameCallback(FrameCallback callback) {
    persistentFrameCallback = callback;
  }

  @override
  bool hasScheduledFrame = true;

  @override
  Future<void> get endOfFrame => Future<void>.value();
}
