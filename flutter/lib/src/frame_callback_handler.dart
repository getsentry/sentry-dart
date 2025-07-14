import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

abstract class FrameCallbackHandler {
  void addPostFrameCallback(FrameCallback callback);
  void removeTimingsCallback(TimingsCallback callback);
  void addTimingsCallback(TimingsCallback callback);
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
  void addTimingsCallback(TimingsCallback callback) {
    try {
      WidgetsBinding.instance.addTimingsCallback(callback);
    } catch (_) {}
  }

  @override
  void removeTimingsCallback(TimingsCallback callback) {
    try {
      WidgetsBinding.instance.removeTimingsCallback(callback);
    } catch (_) {}
  }
}
