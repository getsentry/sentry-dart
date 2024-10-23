// ignore_for_file: invalid_use_of_internal_member

import 'dart:collection';
import 'package:meta/meta.dart';
import '../../sentry_flutter.dart';

/// Singleton frame tracker to collect frames drawn by the Flutter SDK.
///
/// The tracker needs to be initialized first via [SentryFrameTrackingBindingMixin.initializeFrameTracker]
/// otherwise the tracker won't collect frames in the mixin.
///
/// The order in which [startFrame] and [endFrame] is called is sequential
/// and depends on Flutter to be accurate and precise. Each tracked frame is
/// aimed to replicate the build duration that you would receive from [addTimingsCallback].
@internal
class SentryFrameTracker {
  SentryFrameTracker._privateConstructor(this._options);

  static SentryFrameTracker? _instance;

  factory SentryFrameTracker(SentryFlutterOptions options) {
    _instance ??= SentryFrameTracker._privateConstructor(options);
    return _instance!;
  }

  /// List of frame timings that holds delayed frames (slow and frozen frames).
  /// We don't keep track of normal frames since we can estimate the number of
  /// normal frames based on the span duration and the expected frame duration.
  // todo: since startFrame and endFrame is always called sequentially by Flutter we maybe don't need a SplayTree
  final SplayTreeSet<SentryFrameTiming> _delayedFrames =
      SplayTreeSet<SentryFrameTiming>((a, b) => a.compareTo(b));

  final SentryFlutterOptions? _options;
  DateTime? _currentFrameStartTimestamp;
  bool _isTrackingActive = false;

  /// When we reach this limit, we will clear the state of the tracker.
  /// Realistically this won't happen since we only track slow or frozen frames
  /// but it gives us a safeguard if that case ever happens.
  final _maxTrackedFrames = 10000;

  Duration? get expectedFrameDuration => _expectedFrameDuration;
  Duration? _expectedFrameDuration;

  void setExpectedFrameDuration(Duration expectedFrameDuration) {
    _expectedFrameDuration ??= expectedFrameDuration;
  }

  /// Marks the start of a frame.
  @pragma('vm:prefer-inline')
  void startFrame() {
    if (!_isTrackingActive || _options?.enableFramesTracking == false) {
      return;
    }

    _currentFrameStartTimestamp = _options?.clock();
  }

  /// Marks the end of a frame.
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
    if (frameTiming.duration > expectedFrameDuration!) {
      _delayedFrames.add(frameTiming);
    }
    _resetCurrentFrame();

    if (_delayedFrames.length > _maxTrackedFrames) {
      _options?.logger(SentryLevel.warning,
          'Frame tracker: number of frames in memory limit reached. Dropping frame metrics.');
      clear();
    }
  }

  void _resetCurrentFrame() {
    _currentFrameStartTimestamp = null;
  }

  /// Resumes the collecting of frames.
  void resume() {
    _isTrackingActive = true;
  }

  /// Pauses the collecting of frames.
  void pause() {
    _isTrackingActive = false;
    _currentFrameStartTimestamp = null; // Reset any ongoing frame
  }

  /// Retrieves the frames the intersect with the provided [startTimestamp] and [endTimestamp].
  List<SentryFrameTiming> getFramesIntersecting(
      {required DateTime startTimestamp, required DateTime endTimestamp}) {
    return _delayedFrames.where((frame) {
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

  /// Removes frames whose endTimestamp is before [spanStartTimestamp].
  /// This should be called whenever a span finishes.
  void removeFramesBefore(DateTime spanStartTimestamp) {
    if (_delayedFrames.isEmpty) return;
    _delayedFrames.removeWhere(
        (frame) => frame.endTimestamp.isBefore(spanStartTimestamp));
  }

  /// Clears the state of the tracker.
  void clear() {
    _delayedFrames.clear();
    pause();
  }

  @visibleForTesting
  List<SentryFrameTiming> get delayedFrames => _delayedFrames.toList();

  @visibleForTesting
  bool get isTrackingActive => _isTrackingActive;

  @visibleForTesting
  int get maxTrackedFrames => _maxTrackedFrames;

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
