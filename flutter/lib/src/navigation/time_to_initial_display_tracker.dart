import 'dart:async';

import 'package:flutter/widgets.dart';

class TTIDEndTimeTracker {
  static final TTIDEndTimeTracker _instance =
      TTIDEndTimeTracker._internal();
  factory TTIDEndTimeTracker() => _instance;
  TTIDEndTimeTracker._internal();

  bool _isManual = false;
  Completer<DateTime>? _trackingCompleter;

  /// Starts the TTID end time tracking process and returns a Future that completes
  /// with the tracking duration when tracking is completed.
  Future<DateTime>? determineEndTime() {
    _trackingCompleter = Completer<DateTime>();

    // Schedules a check at the end of the frame to determine if the tracking
    // should be completed immediately (approximation mode) or deferred (manual mode).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isManual) {
        completeTracking();
      }
    });

    return _trackingCompleter?.future;
  }

  void markAsManual() {
    _isManual = true;
  }

  void completeTracking() {
    if (_trackingCompleter != null && !_trackingCompleter!.isCompleted) {
      final endTime = DateTime.now();
      // Reset after completion
      _isManual = false;
      _trackingCompleter?.complete(endTime);
    }
  }
}
