import 'dart:collection';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';

import '../sentry_flutter.dart';

import 'frame_callback_handler.dart';
import 'native/sentry_native_binding.dart';

@internal
class SpanFrameMetricsCollector implements PerformanceContinuousCollector {
  static const _frozenFrameThresholdMs = 700;
  static const totalFramesKey = 'frames.total';
  static const framesDelayKey = 'frames.delay';
  static const slowFramesKey = 'frames.slow';
  static const frozenFramesKey = 'frames.frozen';

  final SentryFlutterOptions options;
  final FrameCallbackHandler _frameCallbackHandler;
  final SentryNativeBinding? _native;

  final bool _isTestMode;

  /// Stores frame timestamps and their durations in milliseconds.
  /// Keys are frame timestamps, values are frame durations.
  /// The timestamps mark the end of the frame.
  final frames = SplayTreeMap<DateTime, int>();

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
      {FrameCallbackHandler? frameCallbackHandler,
      SentryNativeBinding? native,
      @internal bool isTestMode = false})
      : _frameCallbackHandler =
            frameCallbackHandler ?? DefaultFrameCallbackHandler(),
        _native = native ?? SentryFlutter.native,
        _isTestMode = isTestMode;

  @override
  Future<void> onSpanStarted(ISentrySpan span) async {
    if (span is NoOpSentrySpan || !options.enableFramesTracking) {
      return;
    }

    final fetchedDisplayRefreshRate = await _native?.displayRefreshRate();
    if (fetchedDisplayRefreshRate != null) {
      options.logger(SentryLevel.debug,
          'Retrieved display refresh rate at $fetchedDisplayRefreshRate');
      displayRefreshRate = fetchedDisplayRefreshRate;
    } else {
      options.logger(SentryLevel.debug,
          'Could not fetch display refresh rate, keeping at 60hz by default');
    }

    activeSpans.add(span);
    startFrameTracking();
  }

  @override
  Future<void> onSpanFinished(ISentrySpan span, DateTime endTimestamp) async {
    if (span is NoOpSentrySpan || !activeSpans.contains(span)) return;

    final frameMetrics =
        calculateFrameMetrics(span, endTimestamp, displayRefreshRate);
    _applyFrameMetricsToSpan(span, frameMetrics);

    activeSpans.remove(span);
    if (activeSpans.isEmpty) {
      clear();
    } else {
      frames.removeWhere((frameTimestamp, _) =>
          frameTimestamp.isBefore(activeSpans.first.startTimestamp));
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
      _frameCallbackHandler.addPersistentFrameCallback(measureFrameDuration);
      _isTrackingRegistered = true;
    }
  }

  /// Records the duration of a single frame and stores it in [frames].
  ///
  /// This method is called for each frame when frame tracking is active.
  Future<void> measureFrameDuration(Duration duration) async {
    // Using the stopwatch to measure the frame duration is flaky in ci
    if (_isTestMode) {
      // ignore: invalid_use_of_internal_member
      frames[options.clock().add(duration)] = duration.inMilliseconds;
      return;
    }

    if (_isTrackingPaused) return;

    if (!_stopwatch.isRunning) {
      _stopwatch.start();
    }

    await _frameCallbackHandler.endOfFrame;

    final frameDuration = _stopwatch.elapsedMilliseconds;
    // ignore: invalid_use_of_internal_member
    frames[options.clock()] = frameDuration;

    _stopwatch.reset();

    if (_frameCallbackHandler.hasScheduledFrame == true) {
      _stopwatch.start();
    }
  }

  void _applyFrameMetricsToSpan(
      ISentrySpan span, Map<String, int> frameMetrics) {
    frameMetrics.forEach((key, value) {
      span.setData(key, value);
    });

    // This will call the methods on the tracer, not on the span directly
    if (span is SentrySpan && span.isRootSpan) {
      frameMetrics.forEach((key, value) {
        // ignore: invalid_use_of_internal_member
        span.tracer.setData(key, value);

        // In measurements we change e.g frames.total to frames_total
        // We don't do span.tracer.setMeasurement because setMeasurement in SentrySpan
        // uses the tracer internally
        span.setMeasurement(key.replaceAll('.', '_'), value);
      });
    }
  }

  @visibleForTesting
  Map<String, int> calculateFrameMetrics(
      ISentrySpan span, DateTime spanEndTimestamp, int displayRefreshRate) {
    if (frames.isEmpty) {
      options.logger(
          SentryLevel.info, 'No frame durations available in frame tracker.');
      return {};
    }

    final expectedFrameDuration = ((1 / displayRefreshRate) * 1000).toInt();

    int slowFramesCount = 0;
    int frozenFramesCount = 0;
    int slowFramesDuration = 0;
    int frozenFramesDuration = 0;
    int framesDelay = 0;

    for (final entry in frames.entries) {
      final frameDuration = entry.value;
      final frameEndTimestamp = entry.key;
      final frameStartMs =
          frameEndTimestamp.millisecondsSinceEpoch - frameDuration;
      final frameEndMs = frameEndTimestamp.millisecondsSinceEpoch;
      final spanStartMs = span.startTimestamp.millisecondsSinceEpoch;
      final spanEndMs = spanEndTimestamp.millisecondsSinceEpoch;

      final frameFullyContainedInSpan =
          frameEndMs <= spanEndMs && frameStartMs >= spanStartMs;
      final frameStartsBeforeSpan =
          frameStartMs < spanStartMs && frameEndMs > spanStartMs;
      final frameEndsAfterSpan =
          frameStartMs < spanEndMs && frameEndMs > spanEndMs;
      final framePartiallyContainedInSpan =
          frameStartsBeforeSpan || frameEndsAfterSpan;

      int effectiveDuration = 0;
      int effectiveDelay = 0;

      if (frameFullyContainedInSpan) {
        effectiveDuration = frameDuration;
        effectiveDelay = max(0, frameDuration - expectedFrameDuration);
      } else if (framePartiallyContainedInSpan) {
        final intersectionStart = max(frameStartMs, spanStartMs);
        final intersectionEnd = min(frameEndMs, spanEndMs);
        effectiveDuration = intersectionEnd - intersectionStart;

        final fullFrameDelay = max(0, frameDuration - expectedFrameDuration);
        final intersectionRatio = effectiveDuration / frameDuration;
        effectiveDelay = (fullFrameDelay * intersectionRatio).round();
      } else if (frameStartMs > spanEndMs) {
        // Other frames will be newer than this span, as frames are ordered
        break;
      } else {
        // Frame is completely outside the span, skip it
        continue;
      }

      if (effectiveDuration > _frozenFrameThresholdMs) {
        frozenFramesCount++;
        frozenFramesDuration += effectiveDuration;
      } else if (effectiveDuration > expectedFrameDuration) {
        slowFramesCount++;
        slowFramesDuration += effectiveDuration;
      }

      framesDelay += effectiveDelay;
    }

    final spanDuration =
        spanEndTimestamp.difference(span.startTimestamp).inMilliseconds;
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
      SpanFrameMetricsCollector.totalFramesKey: totalFramesCount.toInt(),
      SpanFrameMetricsCollector.framesDelayKey: framesDelay,
      SpanFrameMetricsCollector.slowFramesKey: slowFramesCount,
      SpanFrameMetricsCollector.frozenFramesKey: frozenFramesCount,
    };
  }

  @override
  void clear() {
    _isTrackingPaused = true;
    frames.clear();
    activeSpans.clear();
    displayRefreshRate = 60;
  }
}
