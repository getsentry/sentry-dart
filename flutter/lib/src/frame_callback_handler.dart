import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

abstract class FrameCallbackHandler {
  void addPostFrameCallback(FrameCallback callback);
  void addPersistentFrameCallback(FrameCallback callback);
  Future<void> get endOfFrame;
  bool get hasScheduledFrame;
}

class DefaultFrameCallbackHandler implements FrameCallbackHandler {
  @override
  void addPostFrameCallback(FrameCallback callback) {
    try {
      /// Flutter >= 2.12 throws if SchedulerBinding.instance isn't initialized.
      SchedulerBinding.instance.addPostFrameCallback(callback);
    } catch (_) {}
  }

  @override
  void addPersistentFrameCallback(FrameCallback callback) {
    try {
      WidgetsBinding.instance.addPersistentFrameCallback(callback);
    } catch (_) {}
  }

  @override
  Future<void> get endOfFrame async {
    try {
      await WidgetsBinding.instance.endOfFrame;
    } catch (_) {}
  }

  @override
  bool get hasScheduledFrame => WidgetsBinding.instance.hasScheduledFrame;
}
