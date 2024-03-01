import 'package:flutter/scheduler.dart';

abstract class FrameCallbackHandler {
  void addPostFrameCallback(FrameCallback callback);
}

class DefaultFrameCallbackHandler implements FrameCallbackHandler {
  @override
  void addPostFrameCallback(FrameCallback callback) {
    SchedulerBinding.instance.addPostFrameCallback(callback);
  }
}
