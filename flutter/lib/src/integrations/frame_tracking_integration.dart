import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:sentry/sentry.dart';
import '../sentry_flutter_options.dart';
import 'integrations.dart';

class FrameTrackingIntegration extends Integration<SentryFlutterOptions> {
  FrameTrackingIntegration(this._schedulerBindingProvider);

  final SchedulerBindingProvider _schedulerBindingProvider;
  TimingsCallback? _timingsCallback;

  final _frameBudget = Duration(milliseconds: 16);
  final _frozenFrameDuration = Duration(milliseconds: 700);

  var _totalFrames = 0;
  var _slowFrames = 0;
  var _frozenFrames = 0;

  bool get isActive => _timingsCallback != null;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    final schedulerBinding = _schedulerBindingProvider();
    if (schedulerBinding != null) {
      final timingsCallback = (List<FrameTiming> timings) {
        timings.forEach(_updateFrames);
      };
      schedulerBinding.addTimingsCallback(timingsCallback);
      _timingsCallback = timingsCallback;
    } else {
      options.logger(SentryLevel.debug,
          'Scheduler binding is null. Can\'t detect frame timings.');
    }
    options.sdk.addIntegration('frameTrackingIntegration');
  }

  @override
  FutureOr<void> close() {
    final timingsCallback = _timingsCallback;
    final schedulerBinding = _schedulerBindingProvider();
    if (schedulerBinding != null && timingsCallback != null) {
      schedulerBinding.removeTimingsCallback(timingsCallback);
    }
  }

  void beginFramesCollection() {
    _totalFrames = 0;
    _slowFrames = 0;
    _frozenFrames = 0;
  }

  Map<String, SentryMeasurement> endFramesCollection() {
    final total = SentryMeasurement.totalFrames(_totalFrames);
    final slow = SentryMeasurement.slowFrames(_slowFrames);
    final frozen = SentryMeasurement.frozenFrames(_frozenFrames);
    return {
      total.name: total,
      slow.name: slow,
      frozen.name: frozen,
    };
  }

  // Helper

  void _updateFrames(FrameTiming timing) {
    _totalFrames += 1;
    final isSlowFrame = timing.totalSpan > _frameBudget;
    if (isSlowFrame) {
      _slowFrames += 1;
    }
    final isFrozenFrame = timing.totalSpan > _frozenFrameDuration;
    if (isFrozenFrame) {
      _frozenFrames += 1;
    }
  }
}
