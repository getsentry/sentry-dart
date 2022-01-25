import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';

class FrameTracker {
  FrameTracker({
    this.slowFrameThreshold = const Duration(milliseconds: 16),
    this.frozenFrameThreshold = const Duration(milliseconds: 500),
    required WidgetsBinding binding,
  }) : _binding = binding;

  final WidgetsBinding _binding;

  SingletonFlutterWindow get window => _binding.window;

  final Duration slowFrameThreshold;
  final Duration frozenFrameThreshold;

  DateTime? _timeStamp;

  var _frameCount = 0;
  var _slowCount = 0;
  var _frozenCount = 0;

  void _frameCallback(Duration _) {
    final timeStamp = _timeStamp;
    if (timeStamp == null) {
      return;
    }

    // postFrameCallbacks are called just once,
    // so we have to add it each frame.
    _binding.addPostFrameCallback(_frameCallback);

    final now = DateTime.now();
    _timeStamp = now;
    final duration = timeStamp.difference(now).abs();

    if (duration > frozenFrameThreshold) {
      _frozenCount++;
    } else if (duration > slowFrameThreshold) {
      _slowCount++;
    }

    _frameCount++;
  }

  void start() {
    _timeStamp = DateTime.now();
    _binding.addPostFrameCallback(_frameCallback);
  }

  List<SentryMeasurement> finish() {
    final metrics = [
      SentryMeasurement.totalFrames(_frameCount),
      SentryMeasurement.frozenFrames(_frozenCount),
      SentryMeasurement.slowFrames(_slowCount),
    ];

    _reset();
    return metrics;
  }

  void _reset() {
    _timeStamp = null;
    _frameCount = 0;
    _slowCount = 0;
    _frozenCount = 0;
  }
}
