// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

class FrameTracker {
  FrameTracker({SentryOptions? options})
      : _options = options ?? Sentry.currentHub.options;

  /// Exceeded frames are frames that are either slow or frozen.
  // TODO: ensure this is immutable externally
  List<SentryFrameTiming> get exceededFrames =>
      List.unmodifiable(_exceededFrames);
  final List<SentryFrameTiming> _exceededFrames = [];

  DateTime? _currentFrameStartTimestamp;
  final SentryOptions _options;

  /// Indicates whether the frame tracker is active.
  /// Tracking needs to be enabled externally like span frame collector.
  bool _isTracking = false;

  /// Starts tracking a new frame.
  @pragma('vm:prefer-inline')
  void startFrame() {
    if (!_isTracking) {
      // Frame tracking is paused; do nothing.
      return;
    }
    _currentFrameStartTimestamp = _options.clock();
  }

  /// Ends tracking the current frame.
  @pragma('vm:prefer-inline')
  void endFrame() {
    if (!_isTracking) {
      // Frame tracking is paused; do nothing.
      return;
    }
    final startTime = _currentFrameStartTimestamp;
    if (startTime != null) {
      final endTimestamp = _options.clock();
      final frameTiming = SentryFrameTiming(startTime, endTimestamp);
      _exceededFrames.add(frameTiming);
      _currentFrameStartTimestamp = null;
    }
  }

  /// Pauses frame tracking.
  void pause() {
    _isTracking = false;
    _currentFrameStartTimestamp = null; // Reset any ongoing frame
  }

  /// Resumes frame tracking.
  void resume() {
    _isTracking = true;
  }

  /// Removes frames whose endTimestamp is before [time].
  void removeFramesBefore(DateTime time) {
    _exceededFrames.removeWhere((frame) => frame.endTimestamp.isBefore(time));
  }

  void clear() {
    _exceededFrames.clear();
    _currentFrameStartTimestamp = null;
  }
}

/// Frame timing that represents an approximation of the frame's build duration.
@internal
class SentryFrameTiming {
  final DateTime startTimestamp;
  final DateTime endTimestamp;

  late final duration = endTimestamp.difference(startTimestamp);

  SentryFrameTiming(
    this.startTimestamp,
    this.endTimestamp,
  );
}
