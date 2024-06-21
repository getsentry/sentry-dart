import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';

import '../sentry_flutter.dart';

import 'frame_callback_handler.dart';
import 'native/sentry_native.dart';

@internal
class SpanFrameMetricsCollector implements PerformanceContinuousCollector {
  final SentryFlutterOptions options;
  final FrameCallbackHandler? _frameCallbackHandler;
  final SentryNative? _native;

  /// Stores frame timestamps and their durations in milliseconds.
  /// Keys are frame timestamps, values are frame durations.
  final frameDurations = SplayTreeMap<DateTime, int>();

  /// Stores the spans that are actively being tracked.
  /// After the frames are calculated and stored in the span the span is removed from this list.
  final activeSpans = SplayTreeSet<ISentrySpan>(
      (a, b) => a.startTimestamp.compareTo(b.startTimestamp));

  bool get isTrackingPaused => _isTrackingPaused;
  bool _isTrackingPaused = true;

  bool get isTrackingRegistered => _isTrackingRegistered;
  bool _isTrackingRegistered = false;

  int displayRefreshRate = 60;

  final _stopwatch = Stopwatch();

  SpanFrameMetricsCollector(this.options,
      {FrameCallbackHandler? frameCallbackHandler, SentryNative? native})
      : _frameCallbackHandler =
            frameCallbackHandler ?? DefaultFrameCallbackHandler(),
        _native = native ?? SentryFlutter.native;

  @override
  Future<void> onSpanStarted(ISentrySpan span) async {
    if (span is NoOpSentrySpan || !options.enableFramesTracking) {
      return;
    }

    final fetchedDisplayRefreshRate = await _native?.displayRefreshRate();
    if (fetchedDisplayRefreshRate != null) {
      options.logger(SentryLevel.info,
          'Retrieved display refresh rate at $fetchedDisplayRefreshRate');
      displayRefreshRate = fetchedDisplayRefreshRate;
    }

    activeSpans.add(span);
    startFrameTracking();
  }

  @override
  Future<void> onSpanFinished(ISentrySpan span, DateTime endTimestamp) async {
    if (span is NoOpSentrySpan || !options.enableFramesTracking) {
      return Future.value();
    }

    await recordSpanFrameMetrics(span, endTimestamp);

    if (activeSpans.isEmpty) {
      clear();
    } else {
      final oldestSpan = activeSpans.first;
      frameDurations.removeWhere((key, value) {
        return key.isBefore(oldestSpan.startTimestamp);
      });
    }
  }

  /// Calls [WidgetsBinding.instance.addPersistentFrameCallback] which cannot be unregistered
  /// and exists for the duration of the application's lifetime.
  ///
  /// Stopping the frame tracking means setting [isTrackingPaused] is `true`
  /// to prevent actions being done when the frame callback is triggered.
  void startFrameTracking() {
    _isTrackingPaused = false;

    if (!_isTrackingRegistered) {
      _frameCallbackHandler?.addPersistentFrameCallback(measureFrameDuration);
      _isTrackingRegistered = true;
    }
  }

  /// Records the duration of a single frame and stores it in [frameDurations].
  ///
  /// This method is called for each frame when frame tracking is active.
  void measureFrameDuration(Duration duration) async {
    if (_isTrackingPaused) return;

    if (!_stopwatch.isRunning) {
      _stopwatch.start();
    }

    await _frameCallbackHandler?.endOfFrame;

    final frameDuration = _stopwatch.elapsedMilliseconds;
    // ignore: invalid_use_of_internal_member
    frameDurations[getUtcDateTime()] = frameDuration;

    _stopwatch.reset();

    if (_frameCallbackHandler?.hasScheduledFrame == true) {
      _stopwatch.start();
    }
  }

  Future<void> recordSpanFrameMetrics(
      ISentrySpan span, DateTime endTimestamp) async {
    activeSpans.removeWhere(
        (element) => element.context.spanId == span.context.spanId);

    final frameMetrics =
        calculateFrameMetrics(span, endTimestamp, displayRefreshRate);

    frameMetrics.forEach((key, value) {
      span.setData(key, value);
    });

    // This will call the methods on the tracer, not on the span directly
    if (span is SentrySpan && span.isRootSpan) {
      frameMetrics.forEach((key, value) {
        // ignore: invalid_use_of_internal_member
        span.tracer.setData(key, value);
      });
      frameMetrics.forEach((key, value) {
        // In measurements we change e.g frames.total to frames_total
        span.setMeasurement(key.replaceAll('.', '_'), value);
      });
    }
  }

  Map<String, int> calculateFrameMetrics(
      ISentrySpan span, DateTime endTimestamp, int displayRefreshRate) {
    const frozenFrameThresholdMs = 700;
    final expectedFrameDuration = ((1 / displayRefreshRate) * 1000).toInt();

    // Filter frame durations within the span's time range
    final timestamps = frameDurations.keys
        .takeWhile((value) =>
            value.isBefore(endTimestamp) && value.isAfter(span.startTimestamp))
        .toList();

    if (timestamps.isEmpty) {
      options.logger(
          SentryLevel.info, 'No frame durations available in frame tracker.');
      return {};
    }

    int slowFramesCount = 0;
    int frozenFramesCount = 0;
    int slowFramesDuration = 0;
    int frozenFramesDuration = 0;
    int framesDelay = 0;

    for (final timestamp in timestamps) {
      final frameDuration = frameDurations[timestamp] ?? 0;

      if (frameDuration > frozenFrameThresholdMs) {
        frozenFramesCount += 1;
        frozenFramesDuration += frameDuration;
      } else if (frameDuration > expectedFrameDuration) {
        slowFramesCount += 1;
        slowFramesDuration += frameDuration;
      }

      if (frameDuration > expectedFrameDuration) {
        framesDelay += frameDuration - expectedFrameDuration;
      }
    }

    final spanDuration =
        endTimestamp.difference(span.startTimestamp).inMilliseconds;
    final totalFramesCount =
        ((spanDuration - (slowFramesDuration + frozenFramesDuration)) /
                expectedFrameDuration) +
            slowFramesCount +
            frozenFramesCount;

    if (totalFramesCount < 0 ||
        framesDelay < 0 ||
        slowFramesCount < 0 ||
        frozenFramesCount < 0) {
      options.logger(SentryLevel.warning,
          'Negative frame metrics calculated. Dropping frame metrics.');
      return {};
    }

    return {
      "frames.total": totalFramesCount.toInt(),
      "frames.delay": framesDelay,
      "frames.slow": slowFramesCount,
      "frames.frozen": frozenFramesCount,
    };
  }

  @override
  void clear() {
    _isTrackingPaused = true;
    frameDurations.clear();
    activeSpans.clear();
    displayRefreshRate = 60;
  }
}
