// ignore_for_file: invalid_use_of_internal_member

import 'dart:collection';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';

/// Singleton of a frame tracker.
/// This is used in [SentryFrameTrackingBindingMixin] to gather the build duration of
/// individual frames. The frame tracking mechanism and the gathered frames are
/// controlled and consumed by [SpanFrameMetricsCollector].
@internal
class SentryFrameTracker {
  SentryFrameTracker._privateConstructor(this._options);

  static SentryFrameTracker? _instance;

  factory SentryFrameTracker(SentryFlutterOptions options) {
    _instance ??= SentryFrameTracker._privateConstructor(options);
    return _instance!;
  }

  /// List of frame timings that exceeded the expected frame duration threshold.
  final SplayTreeSet<SentryFrameTiming> _exceededFrames =
      SplayTreeSet<SentryFrameTiming>((a, b) => a.compareTo(b));

  final SentryFlutterOptions? _options;
  DateTime? _currentFrameStartTimestamp;
  bool _isTrackingActive = false;

  Duration? get expectedFrameDuration => _expectedFrameDuration;
  Duration? _expectedFrameDuration;

  void setExpectedFrameDuration(Duration expectedFrameDuration) {
    _expectedFrameDuration ??= expectedFrameDuration;
  }

  List<SentryFrameTiming> getFramesIntersecting(
      {required DateTime startTimestamp, required DateTime endTimestamp}) {
    return _exceededFrames.where((frame) {
      // Fully contained or exactly matching
      final fullyContainedOrMatching =
          frame.startTimestamp.compareTo(startTimestamp) >= 0 &&
              frame.endTimestamp.compareTo(endTimestamp) <= 0;

      // Partially contained, starts before range, ends within range
      final startsBeforeEndsWithin =
          frame.startTimestamp.isBefore(startTimestamp) &&
              frame.endTimestamp.isAfter(startTimestamp) &&
              frame.endTimestamp.isBefore(endTimestamp);

      // Partially contained, starts within range, ends after range
      final startsWithinEndsAfter =
          frame.startTimestamp.isAfter(startTimestamp) &&
              frame.startTimestamp.isBefore(endTimestamp) &&
              frame.endTimestamp.isAfter(endTimestamp);

      return fullyContainedOrMatching ||
          startsBeforeEndsWithin ||
          startsWithinEndsAfter;
    }).toList(growable: false);
  }

  @pragma('vm:prefer-inline')
  void startFrame() {
    if (!_isTrackingActive || _options?.enableFramesTracking == false) {
      return;
    }

    _currentFrameStartTimestamp = _options?.clock();
  }

  @pragma('vm:prefer-inline')
  void endFrame() {
    if (!_isTrackingActive || _options?.enableFramesTracking == false) {
      return;
    }

    final endTimestamp = _options?.clock();
    final startTimestamp = _currentFrameStartTimestamp;

    if (!_isFrameValid(startTimestamp, endTimestamp)) {
      _resetCurrentFrame();
      return;
    }

    _processFrame(startTimestamp!, endTimestamp!);
  }

  bool _isFrameValid(DateTime? startTimestamp, DateTime? endTimestamp) {
    return startTimestamp != null &&
        endTimestamp != null &&
        _expectedFrameDuration != null;
  }

  void _processFrame(DateTime startTimestamp, DateTime endTimestamp) {
    final frameTiming = SentryFrameTiming(
        startTimestamp: startTimestamp, endTimestamp: endTimestamp);
    if (frameTiming.duration > _expectedFrameDuration!) {
      _exceededFrames.add(frameTiming);
    }
    _resetCurrentFrame();
  }

  void _resetCurrentFrame() {
    _currentFrameStartTimestamp = null;
  }

  /// Resumes frame tracking if it's not currently active.
  void resume() {
    _isTrackingActive = true;
  }

  /// Pauses frame tracking.
  void pause() {
    _isTrackingActive = false;
    _currentFrameStartTimestamp = null; // Reset any ongoing frame
  }

  /// Removes frames whose endTimestamp is before [spanStartTimestamp].
  /// This should be called whenever a span finishes.
  void removeFramesBefore(DateTime spanStartTimestamp) {
    if (_exceededFrames.isEmpty) return;
    _exceededFrames.removeWhere(
        (frame) => frame.endTimestamp.isBefore(spanStartTimestamp));
  }

  void clear() {
    _exceededFrames.clear();
    pause();
  }

  @visibleForTesting
  List<SentryFrameTiming> get exceededFrames => _exceededFrames.toList();

  @visibleForTesting
  bool get isTrackingActive => _isTrackingActive;

  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }
}

/// Frame timing that represents an approximation of the frame's build duration.
@internal
class SentryFrameTiming {
  final DateTime startTimestamp;
  final DateTime endTimestamp;

  late final duration = endTimestamp.difference(startTimestamp);

  // Implement compareTo for SplayTreeSet sorting
  int compareTo(SentryFrameTiming other) =>
      endTimestamp.compareTo(other.endTimestamp);

  SentryFrameTiming({
    required this.startTimestamp,
    required this.endTimestamp,
  });
}
