import 'package:flutter/scheduler.dart';

abstract class FrameCallbackHandler {
  void addPostFrameCallback(FrameCallback callback);
}

class DefaultFrameCallbackHandler implements FrameCallbackHandler {
  @override
  void addPostFrameCallback(FrameCallback callback) {
    try {
      /// Flutter >= 2.12 throws if SchedulerBinding.instance isn't initialized.
      SchedulerBinding.instance.addPostFrameCallback(callback);
    } catch (_) {}
  }
}
