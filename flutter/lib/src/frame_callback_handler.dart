import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

typedef SentryTimingsCallback = void Function(List<FrameTiming> timings);

abstract class FrameCallbackHandler {
  void addPostFrameCallback(FrameCallback callback);
  void removeTimingsCallback(SentryTimingsCallback callback);
  void addTimingsCallback(SentryTimingsCallback callback);
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
  void addTimingsCallback(SentryTimingsCallback callback) {
    try {
      WidgetsBinding.instance.addTimingsCallback(callback);
    } catch (_) {}
  }

  @override
  void removeTimingsCallback(SentryTimingsCallback callback) {
    try {
      WidgetsBinding.instance.removeTimingsCallback(callback);
    } catch (_) {}
  }
}
