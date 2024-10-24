// ignore_for_file: invalid_use_of_internal_member

import 'dart:math';

import 'package:meta/meta.dart';
import '../../sentry_flutter.dart';

/// 30s span duration at 120fps = 3600 frames
/// This is just an upper limit, ensuring that the buffer does not grow
/// indefinitely in case of a long running span.
/// Realistically this won't happen since we only track slow or frozen frames
/// but it's going to help us safeguard in the rare cases when it happens.
///
/// If this limit is reached, we stop collecting frames until all active spans
/// have finished processing.
const maxFramesCount = 3600;

/// The duration at which we consider a frame 'frozen'
const _frozenFrameThreshold = Duration(milliseconds: 700);

/// Singleton frame tracker to collect delayed frames processed by the Flutter SDK.
///
/// The tracker needs to be initialized first via [SentryFrameTrackingBindingMixin.initializeFrameTracker]
/// otherwise the tracker won't collect frames.
///
/// The order in which [startFrame] and [endFrame] is called is sequential
/// and depends on Flutter to be accurate and precise. Each tracked frame is
/// aimed to replicate the build duration that you would receive from [addTimingsCallback].
@internal
class SentryDelayedFramesTracker {
  SentryDelayedFramesTracker(this._options, this._expectedFrameDuration);

  /// List of frame timings that holds delayed frames (slow and frozen frames).
  /// We don't keep track of normal frames since we can estimate the number of
  /// normal frames based on the span duration and the expected frame duration.
  /// Since startFrame and endFrame is always called sequentially by Flutter we
  /// don't need a SplayTree
  final List<SentryFrameTiming> _delayedFrames = [];
  final SentryFlutterOptions _options;
  final Duration _expectedFrameDuration;
  DateTime? _currentFrameStartTimestamp;
  bool _isTrackingActive = false;

  /// Marks the start of a frame.
  @pragma('vm:prefer-inline')
  void startFrame() {
    if (!_isTrackingActive || _options.enableFramesTracking == false) {
      return;
    }

    _currentFrameStartTimestamp = _options.clock();
  }

  /// Marks the end of a frame.
  @pragma('vm:prefer-inline')
  void endFrame() {
    if (!_isTrackingActive || !_options.enableFramesTracking) {
      return;
    }

    final endTimestamp = _options.clock();
    final startTimestamp = _currentFrameStartTimestamp;

    if (!_isFrameValid(startTimestamp, endTimestamp)) {
      _resetCurrentFrame();
      return;
    }

    _processFrame(startTimestamp!, endTimestamp);
  }

  bool _isFrameValid(DateTime? startTimestamp, DateTime? endTimestamp) {
    return startTimestamp != null && endTimestamp != null;
  }

  void _processFrame(DateTime startTimestamp, DateTime endTimestamp) {
    final duration = endTimestamp.difference(startTimestamp);
    if (duration > _expectedFrameDuration) {
      if (_delayedFrames.length < maxFramesCount) {
        final frameTiming = SentryFrameTiming(
            startTimestamp: startTimestamp, endTimestamp: endTimestamp);
        _delayedFrames.add(frameTiming);
      } else {
        // buffer is full, we stop collecting frames until all active spans have
        // finished processing
        pause();
      }
    }
    _resetCurrentFrame();
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
  @visibleForTesting
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

  /// Calculates the frame metrics based on start, end timestamps and the
  /// delayed frames metrics. If the delayed frames array is empty then
  /// only the total frames will be calculated.
  SpanFrameMetrics? getFrameMetrics(
      {required DateTime spanStartTimestamp,
      required DateTime spanEndTimestamp}) {
    final relevantFrames = getFramesIntersecting(
        startTimestamp: spanStartTimestamp, endTimestamp: spanEndTimestamp);
    final spanDuration =
        spanEndTimestamp.difference(spanStartTimestamp).inMilliseconds;

    // No slow or frozen frames detected
    if (relevantFrames.isEmpty) {
      return SpanFrameMetrics(
          totalFrameCount:
              (spanDuration / _expectedFrameDuration.inMilliseconds).ceil(),
          slowFrameCount: 0,
          frozenFrameCount: 0,
          framesDelay: 0);
    }

    final spanStartMs = spanStartTimestamp.millisecondsSinceEpoch;
    final spanEndMs = spanEndTimestamp.millisecondsSinceEpoch;
    final expectedDurationMs = _expectedFrameDuration.inMilliseconds;
    final frozenThresholdMs = _frozenFrameThreshold.inMilliseconds;

    int slowFrameCount = 0;
    int frozenFrameCount = 0;
    int slowFramesDuration = 0;
    int frozenFramesDuration = 0;
    int framesDelay = 0;

    for (final timing in delayedFrames) {
      final frameStartMs = timing.startTimestamp.millisecondsSinceEpoch;
      final frameEndMs = timing.endTimestamp.millisecondsSinceEpoch;
      final actualDurationMs = timing.duration.inMilliseconds;

      if (frameEndMs <= spanStartMs) {
        // Frame ends before the span starts, skip it
        continue;
      }

      if (frameStartMs >= spanEndMs) {
        // Frames are ordered, every next frame will start after this span, stop processing
        break;
      }

      // Calculate effective duration and delay
      int effectiveDuration;
      int effectiveDelay;

      if (frameStartMs >= spanStartMs && frameEndMs <= spanEndMs) {
        // Fully contained
        effectiveDuration = actualDurationMs;
        effectiveDelay = max(0, actualDurationMs - expectedDurationMs);
      } else {
        // Partially contained
        final intersectionStart = max(frameStartMs, spanStartMs);
        final intersectionEnd = min(frameEndMs, spanEndMs);
        effectiveDuration = intersectionEnd - intersectionStart;

        final fullFrameDelay = max(0, actualDurationMs - expectedDurationMs);
        final intersectionRatio = effectiveDuration / actualDurationMs;
        effectiveDelay = (fullFrameDelay * intersectionRatio).round();
      }

      // Classify frame
      final isFrozen = effectiveDuration >= frozenThresholdMs;
      final isSlow = effectiveDuration > expectedDurationMs;
      if (isFrozen) {
        frozenFrameCount++;
        frozenFramesDuration += effectiveDuration;
      } else if (isSlow) {
        slowFrameCount++;
        slowFramesDuration += effectiveDuration;
      }

      framesDelay += effectiveDelay;
    }

    final normalFramesCount =
        (spanDuration - (slowFramesDuration + frozenFramesDuration)) /
            _expectedFrameDuration.inMilliseconds;
    final totalFrameCount =
        (normalFramesCount + slowFrameCount + frozenFrameCount).ceil();

    if (totalFrameCount < 0 ||
        slowFrameCount < 0 ||
        frozenFrameCount < 0 ||
        framesDelay < 0) {
      return null;
    }

    if (totalFrameCount < slowFrameCount ||
        totalFrameCount < frozenFrameCount) {
      return null;
    }

    return SpanFrameMetrics(
        totalFrameCount: totalFrameCount,
        slowFrameCount: slowFrameCount,
        frozenFrameCount: frozenFrameCount,
        framesDelay: framesDelay);
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
}

/// Frame timing that represents an approximation of the frame's build duration.
@internal
class SentryFrameTiming {
  final DateTime startTimestamp;
  final DateTime endTimestamp;

  late final duration = endTimestamp.difference(startTimestamp);

  SentryFrameTiming({
    required this.startTimestamp,
    required this.endTimestamp,
  });
}

@internal
class SpanFrameMetrics {
  final int totalFrameCount;
  final int slowFrameCount;
  final int frozenFrameCount;
  final int framesDelay;

  SpanFrameMetrics({
    required this.totalFrameCount,
    required this.slowFrameCount,
    required this.frozenFrameCount,
    required this.framesDelay,
  });

  void applyTo(ISentrySpan span) {
    // If it's a root span, also apply measurements
    if (span is SentrySpan && span.isRootSpan) {
      final tracer = span.tracer;

      _setData(tracer);

      span.setMeasurement(SentryMeasurement.totalFramesName, totalFrameCount);
      span.setMeasurement(SentryMeasurement.slowFramesName, slowFrameCount);
      span.setMeasurement(SentryMeasurement.frozenFramesName, frozenFrameCount);
      span.setMeasurement(SentryMeasurement.framesDelayName, framesDelay);
    } else {
      _setData(span);
    }
  }

  void _setData(ISentrySpan span) {
    span.setData(SpanDataConvention.totalFrames, totalFrameCount);
    span.setData(SpanDataConvention.slowFrames, slowFrameCount);
    span.setData(SpanDataConvention.frozenFrames, frozenFrameCount);
    span.setData(SpanDataConvention.framesDelay, framesDelay);
  }
}
