import 'dart:ui';

import 'package:flutter/widgets.dart';

/// Records the time which a frame takes to draw, if it's above
/// a certain threshold, i.e. [FrameTracker.slowFrameThreshold].
///
/// This should not be added in debug mode because the performance of the debug
/// mode is not indicativ of the performance in release mode.
///
/// Updates are occuring approximately once a second in release mode and
/// approximately once every 100ms in debug and profile builds.
///
/// Remarks:
/// See [SchedulerBinding.addTimingsCallback](https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addTimingsCallback.html)
/// to learn more about the performance impact of using this.
///
/// Adding a `timingsCallback` has a real significant performance impact as
/// noted above. Thus this integration should only be added if it's enabled.
/// The enabled check should not happen inside the `timingsCallback`.
class FrameTracker {
  FrameTracker({
    this.slowFrameThreshold = const Duration(milliseconds: 16),
    this.frozenFrameThreshold = const Duration(milliseconds: 500),
  }) {
    binding.addTimingsCallback(_timingsCallback);
  }

  // Checks wether [FrameTracker] is supported on this Flutter version
  static bool isSupported() {
    try {
      (WidgetsBinding.instance!.window as dynamic).frameData.frameNumber as int;
    } on NoSuchMethodError catch (_) {
      return false;
    }
    return true;
  }

  final WidgetsBinding binding = WidgetsBinding.instance!;
  SingletonFlutterWindow get window => binding.window;

  final Duration slowFrameThreshold;
  final Duration frozenFrameThreshold;

  final List<FrameTiming> _frameTimings = [];

  var startFrameNumber = -1;
  var endFrameNumber = -1;

  void start() {
    startFrameNumber = window.currentFrameNumber;
  }

  Map<String, dynamic> finish() {
    if (startFrameNumber == -1) {
      return {};
    }
    endFrameNumber = window.currentFrameNumber;
    _reset();
    return _listToMetrics(endFrameNumber);
  }

  void _reset() {
    startFrameNumber = -1;
    endFrameNumber = -1;
  }

  Map<String, dynamic> _listToMetrics(int endFrameNumber) {
    final frameInTimeSpan = _frameTimings.where((element) {
      final frame = element.currentFrameNumber;
      return frame > startFrameNumber && frame < endFrameNumber;
    });
    return {
      'measurements': {
        'frames_frozen': {
          'value': frameInTimeSpan
              .where((frame) => frame.totalSpan > frozenFrameThreshold)
              .length,
        },
        'frames_slow': {
          'value': frameInTimeSpan
              .where((frame) => frame.totalSpan > slowFrameThreshold)
              .length,
        },
        'frames_total': {
          'value': frameInTimeSpan.length,
        }
      }
    };
  }

  /// The first frame is sent without batching as per
  /// [WidgetsBinding.addTimingsCallback] docs.
  void _timingsCallback(List<FrameTiming> timings) {
    _frameTimings.addAll(timings);
  }
}

extension _SingletonFlutterWindowExtension on SingletonFlutterWindow {
  int get currentFrameNumber => (this as dynamic).frameData.frameNumber as int;
}

extension _FrameTimingExtension on FrameTiming {
  int get currentFrameNumber => (window as dynamic).frameNumber as int;
}
