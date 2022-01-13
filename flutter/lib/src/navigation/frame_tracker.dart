import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';

class FrameTracker {
  FrameTracker({
    this.slowFrameThreshold = const Duration(milliseconds: 16),
    this.frozenFrameThreshold = const Duration(milliseconds: 500),
    required WidgetsBinding binding,
  }) : _binding = binding;

  static const dataKey = 'measurements';
  final WidgetsBinding _binding;
  bool? _isSupported;

  // Checks wether [FrameTracker] is supported on this Flutter version
  bool get isSupported {
    try {
      (_binding.window as dynamic).frameData.frameNumber as int;
    } on NoSuchMethodError catch (_) {
      return _isSupported ??= false;
    }
    return _isSupported ??= true;
  }

  SingletonFlutterWindow get window => _binding.window;

  final Duration slowFrameThreshold;
  final Duration frozenFrameThreshold;

  var startFrameNumber = -1;
  var endFrameNumber = -1;

  void start() {
    if (!isSupported) {
      return;
    }
    startFrameNumber = window.currentFrameNumber;
  }

  List<SentryMeasurement>? finish() {
    if (!isSupported || startFrameNumber == -1) {
      // Either Flutter doesn't support frame numbers yet
      // or frame tracking hasn't started yet.
      return null;
    }
    endFrameNumber = window.currentFrameNumber;

    final metrics = _listToMetrics(
      startFrameNumber,
      endFrameNumber,
    );
    _reset();
    return metrics;
  }

  void _reset() {
    startFrameNumber = -1;
    endFrameNumber = -1;
  }

  static List<SentryMeasurement> _listToMetrics(
    int startFrameNumber,
    int endFrameNumber,
  ) {
    final frameCount = endFrameNumber - startFrameNumber;

    return [SentryMeasurement.totalFrames(frameCount.toDouble())];
  }
}

extension _SingletonFlutterWindowExtension on SingletonFlutterWindow {
  int get currentFrameNumber => (this as dynamic).frameData.frameNumber as int;
}
