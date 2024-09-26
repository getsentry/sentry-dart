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

  int _totalFrames = 0;
  int _slowFrames = 0;
  int _frozenFrames = 0;
  int _totalDelay = 0;
  int? _expectedFrameDuration;

  /// Stores frame timestamps and their durations in milliseconds.
  /// Keys are frame timestamps, values are frame durations.
  /// The timestamps mark the end of the frame.
  @visibleForTesting
  final frames = SplayTreeMap<DateTime, int>();

  /// Stores the spans that are actively being tracked.
  /// After the frames are calculated and stored in the span the span is removed from this list.
  @visibleForTesting
  final activeSpans = SplayTreeSet<ISentrySpan>(
      (a, b) => a.startTimestamp.compareTo(b.startTimestamp));

  bool get isTrackingPaused => _isTrackingPaused;
  bool _isTrackingPaused = true;

  bool get isTrackingRegistered => _isTrackingRegistered;
  bool _isTrackingRegistered = false;

  @visibleForTesting
  int? displayRefreshRate;

  @visibleForTesting
  int maxFramesToTrack = 10800;

  final Map<ISentrySpan, SpanMetrics> _spanMetrics = {};

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
    if (fetchedDisplayRefreshRate != null && fetchedDisplayRefreshRate > 0) {
      options.logger(SentryLevel.debug,
          'Retrieved display refresh rate at $fetchedDisplayRefreshRate');
      displayRefreshRate = fetchedDisplayRefreshRate;

      // Start tracking frames only when refresh rate is valid
      _spanMetrics[span] = SpanMetrics();
      activeSpans.add(span);
      startFrameTracking();
    } else {
      options.logger(SentryLevel.debug,
          'Retrieved invalid display refresh rate: $fetchedDisplayRefreshRate. Not starting frame tracking.');
    }
  }

  @override
  Future<void> onSpanFinished(ISentrySpan span, DateTime endTimestamp) async {
    if (span is NoOpSentrySpan || !activeSpans.contains(span)) return;

    if (displayRefreshRate == null || displayRefreshRate! <= 0) {
      options.logger(SentryLevel.warning,
          'Invalid display refresh rate. Skipping frame tracking for all active spans.');
      clear();
      return;
    }

    _expectedFrameDuration = 1000 ~/ displayRefreshRate!;

    final frameMetrics =
        calculateFrameMetrics(span, endTimestamp, displayRefreshRate!);
    _applyFrameMetricsToSpan(span, frameMetrics);

    print('span total frames: ${_spanMetrics[span]!.totalFrames}');
    print('span total delay: ${_spanMetrics[span]!.totalDelay}');
    print('span slow frames: ${_spanMetrics[span]!.slowFrames}');
    print('span frozen frames: ${_spanMetrics[span]!.frozenFrames}');

    activeSpans.remove(span);
    _spanMetrics.remove(span);
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

  DateTime? _lastFrameEnd;

  /// Records the duration of a single frame and stores it in [frames].
  ///
  /// This method is called for each frame when frame tracking is active.
  Future<void> measureFrameDuration(Duration duration) async {
    if (frames.length >= maxFramesToTrack) {
      options.logger(SentryLevel.warning,
          'Frame tracking limit reached. Clearing frames and cancelling frame tracking for all active spans');
      clear();
      return;
    }

    // Using the stopwatch to measure the frame duration is flaky in ci
    if (_isTestMode) {
      // ignore: invalid_use_of_internal_member
      frames[options.clock().add(duration)] = duration.inMilliseconds;
      return;
    }

    print('measureFrameDuration');

    if (_isTrackingPaused) return;

    if (!_stopwatch.isRunning) {
      _stopwatch.start();
    }

    await _frameCallbackHandler.endOfFrame;

    final frameDuration = _stopwatch.elapsedMilliseconds;
    // ignore: invalid_use_of_internal_member
    final frameEnd = options.clock();
    frames[frameEnd] = frameDuration;
    final frameStart = _lastFrameEnd ?? frameEnd.subtract(duration);
    _lastFrameEnd = frameEnd;

    final frameStartMs = frameStart.millisecondsSinceEpoch;
    final frameEndMs = frameEnd.millisecondsSinceEpoch;

    for (final span in activeSpans) {
      final spanStartMs = span.startTimestamp.millisecondsSinceEpoch;
      final spanEndMs = (span.endTimestamp ?? frameEnd).millisecondsSinceEpoch;

      final frameInfo = FrameInfo(
        frameStartMs: frameStartMs,
        frameEndMs: frameEndMs,
        spanStartMs: spanStartMs,
        spanEndMs: spanEndMs,
        frameDuration: frameDuration,
        expectedFrameDuration: _expectedFrameDuration!,
      );

      _spanMetrics[span]?.updateMetrics(
          frameInfo, _expectedFrameDuration!, spanEndMs - spanStartMs);
    }

    // print('frameDuration: $frameDuration ${frames.length}');

    // _updateMetrics(frameDuration);

    _stopwatch.reset();

    if (_frameCallbackHandler.hasScheduledFrame == true) {
      _stopwatch.start();
    }
  }

  void _updateMetrics(Duration frameDuration) {
    _totalFrames++;

    if (frameDuration.inMilliseconds > _frozenFrameThresholdMs) {
      _frozenFrames++;
    } else if (frameDuration.inMilliseconds > _expectedFrameDuration!) {
      _slowFrames++;
    }

    _totalDelay +=
        max(0, frameDuration.inMilliseconds - _expectedFrameDuration!);
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
    final normalFramesCount =
        (spanDuration - (slowFramesDuration + frozenFramesDuration)) /
            expectedFrameDuration;
    final totalFramesCount =
        (normalFramesCount + slowFramesCount + frozenFramesCount).ceil();

    if (totalFramesCount < 0 ||
        framesDelay < 0 ||
        slowFramesCount < 0 ||
        frozenFramesCount < 0) {
      options.logger(SentryLevel.warning,
          'Negative frame metrics calculated. Dropping frame metrics.');
      return {};
    }

    if (totalFramesCount < slowFramesCount ||
        totalFramesCount < frozenFramesCount) {
      options.logger(SentryLevel.warning,
          'Total frames count is less than slow or frozen frames count. Dropping frame metrics.');
      return {};
    }

    print('totalFramesCount: $totalFramesCount');
    print('framesDelay: $framesDelay');
    print('slowFramesCount: $slowFramesCount');
    print('frozenFramesCount: $frozenFramesCount');

    return {
      SpanFrameMetricsCollector.totalFramesKey: totalFramesCount,
      SpanFrameMetricsCollector.framesDelayKey: framesDelay,
      SpanFrameMetricsCollector.slowFramesKey: slowFramesCount,
      SpanFrameMetricsCollector.frozenFramesKey: frozenFramesCount,
    };
  }

  @override
  void clear() {
    _isTrackingPaused = true;
    _stopwatch.reset();
    frames.clear();
    activeSpans.clear();
    displayRefreshRate = null;
  }
}

class FrameInfo {
  final int effectiveDuration;
  final int effectiveDelay;
  final bool isRelevantForSpan;

  FrameInfo._({
    required this.effectiveDuration,
    required this.effectiveDelay,
    required this.isRelevantForSpan,
  });

  factory FrameInfo({
    required int frameStartMs,
    required int frameEndMs,
    required int spanStartMs,
    required int spanEndMs,
    required int frameDuration,
    required int expectedFrameDuration,
  }) {
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
    bool isRelevantForSpan = true;

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
      // Frame is after the span, not relevant
      isRelevantForSpan = false;
    } else {
      // Frame is completely outside the span, not relevant
      isRelevantForSpan = false;
    }

    return FrameInfo._(
      effectiveDuration: effectiveDuration,
      effectiveDelay: effectiveDelay,
      isRelevantForSpan: isRelevantForSpan,
    );
  }
}

class SpanMetrics {
  int totalFrames = 0;
  int slowFrames = 0;
  int frozenFrames = 0;
  int totalDelay = 0;
  double totalFrameDuration = 0.0;
  int slowFramesDuration = 0;
  int frozenFramesDuration = 0;

  void updateMetrics(
      FrameInfo frameInfo, int expectedFrameDuration, int spanDuration) {
    totalFrameDuration += frameInfo.effectiveDuration;

    if (frameInfo.effectiveDuration >
        SpanFrameMetricsCollector._frozenFrameThresholdMs) {
      frozenFrames++;
      frozenFramesDuration += frameInfo.effectiveDuration;
    } else if (frameInfo.effectiveDuration > expectedFrameDuration) {
      slowFrames++;
      slowFramesDuration += frameInfo.effectiveDuration;
    }

    totalDelay += frameInfo.effectiveDelay;
    final normalFramesCount =
        (spanDuration - (slowFramesDuration + frozenFramesDuration)) /
            expectedFrameDuration;
    final totalFramesCount =
        (normalFramesCount + slowFrames + frozenFrames).ceil();
    totalFrames = totalFramesCount;
  }
}
