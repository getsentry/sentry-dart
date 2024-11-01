import 'dart:collection';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';

import '../sentry_flutter.dart';

import 'frame_callback_handler.dart';
import 'native/sentry_native_binding.dart';

@internal
class SpanFrameMetricsCollector implements PerformanceContinuousCollector {
  static const _frozenFrameThreshold = Duration(milliseconds: 700);
  static const totalFramesKey = 'frames.total';
  static const framesDelayKey = 'frames.delay';
  static const slowFramesKey = 'frames.slow';
  static const frozenFramesKey = 'frames.frozen';
  static const estimatedFrameRateKey = 'frames.rate';
  static const relativeFrameDelayKey = 'frames.relative_delay';

  final SentryFlutterOptions options;
  final FrameCallbackHandler _frameCallbackHandler;
  final SentryNativeBinding? _native;

  final bool _isTestMode;

  /// Stores timestamps and durations (in milliseconds) of frames exceeding the expected duration.
  /// Keys are frame timestamps, values are frame durations.
  /// The timestamps mark the end of the frame.
  @visibleForTesting
  final exceededFrames = SplayTreeMap<DateTime, int>();

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
  Duration? expectedFrameDuration;

  @visibleForTesting
  int maxFramesToTrack = 10800;

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
  Future<void> onSpanStarted(ISentrySpan span) =>
      _tryCatch('onSpanStarted', () async {
        if (span is NoOpSentrySpan || !options.enableFramesTracking) {
          return;
        }

        final fetchedDisplayRefreshRate = await _native?.displayRefreshRate();
        if (fetchedDisplayRefreshRate != null &&
            fetchedDisplayRefreshRate > 0) {
          options.logger(SentryLevel.debug,
              'Retrieved display refresh rate at $fetchedDisplayRefreshRate');
          displayRefreshRate = fetchedDisplayRefreshRate;
          expectedFrameDuration = Duration(
              milliseconds: ((1 / fetchedDisplayRefreshRate) * 1000).toInt());

          // Start tracking frames only when refresh rate is valid
          activeSpans.add(span);
          startFrameTracking();
        } else {
          options.logger(SentryLevel.debug,
              'Retrieved invalid display refresh rate: $fetchedDisplayRefreshRate. Not starting frame tracking.');
        }
      });

  @override
  Future<void> onSpanFinished(ISentrySpan span, DateTime endTimestamp) =>
      _tryCatch('onSpanFinished', () async {
        if (span is NoOpSentrySpan || !activeSpans.contains(span)) return;

        if (displayRefreshRate == null || displayRefreshRate! <= 0) {
          options.logger(SentryLevel.warning,
              'Invalid display refresh rate. Skipping frame tracking for all active spans.');
          clear();
          return;
        }

        final frameMetrics =
            calculateFrameMetrics(span, endTimestamp, displayRefreshRate!);
        _applyFrameMetricsToSpan(span, frameMetrics);

        activeSpans.remove(span);
        if (activeSpans.isEmpty) {
          clear();
        } else {
          exceededFrames.removeWhere((frameTimestamp, _) =>
              frameTimestamp.isBefore(activeSpans.first.startTimestamp));
        }
      });

  // TODO: there's already a similar implementation: [SentryNativeSafeInvoker]
  // let's try to reuse it at some point
  Future<void> _tryCatch(String methodName, Future<void> Function() fn) async {
    try {
      return fn();
    } catch (exception, stackTrace) {
      options.logger(
        SentryLevel.error,
        'SpanFrameMetricsCollector $methodName failed',
        exception: exception,
        stackTrace: stackTrace,
      );
      clear();
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

  /// Records the duration of a single frame and stores it in [exceededFrames].
  ///
  /// This method is called for each frame when frame tracking is active.
  Future<void> measureFrameDuration(Duration duration) async {
    if (exceededFrames.length >= maxFramesToTrack) {
      options.logger(SentryLevel.warning,
          'Frame tracking limit reached. Clearing frames and cancelling frame tracking for all active spans');
      clear();
      return;
    }

    if (expectedFrameDuration == null) {
      options.logger(SentryLevel.info,
          'Expected frame duration is null. Cancelling frame tracking for all active spans.');
      clear();
      return;
    }

    // Using the stopwatch to measure the frame duration is flaky in ci
    if (_isTestMode) {
      // ignore: invalid_use_of_internal_member
      exceededFrames[options.clock().add(duration)] = duration.inMilliseconds;
      return;
    }

    if (_isTrackingPaused) return;

    if (!_stopwatch.isRunning) {
      _stopwatch.start();
    }

    await _frameCallbackHandler.endOfFrame;

    final frameDuration = _stopwatch.elapsedMilliseconds;
    if (frameDuration > expectedFrameDuration!.inMilliseconds) {
      // ignore: invalid_use_of_internal_member
      exceededFrames[options.clock()] = frameDuration;
    }

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
    if (exceededFrames.isEmpty) {
      options.logger(
          SentryLevel.info, 'No frame durations available in frame tracker.');
      return {};
    }

    if (expectedFrameDuration == null) {
      options.logger(SentryLevel.info,
          'Expected frame duration is null. Dropping frame metrics.');
      return {};
    }

    int slowFramesCount = 0;
    int frozenFramesCount = 0;
    int slowFramesDuration = 0;
    int frozenFramesDuration = 0;
    int framesDelay = 0;

    for (final entry in exceededFrames.entries) {
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
        effectiveDelay =
            max(0, frameDuration - expectedFrameDuration!.inMilliseconds);
      } else if (framePartiallyContainedInSpan) {
        final intersectionStart = max(frameStartMs, spanStartMs);
        final intersectionEnd = min(frameEndMs, spanEndMs);
        effectiveDuration = intersectionEnd - intersectionStart;

        final fullFrameDelay =
            max(0, frameDuration - expectedFrameDuration!.inMilliseconds);
        final intersectionRatio = effectiveDuration / frameDuration;
        effectiveDelay = (fullFrameDelay * intersectionRatio).round();
      } else if (frameStartMs > spanEndMs) {
        // Other frames will be newer than this span, as frames are ordered
        break;
      }

      if (effectiveDuration >= _frozenFrameThreshold.inMilliseconds) {
        frozenFramesCount++;
        frozenFramesDuration += effectiveDuration;
      } else if (effectiveDuration > expectedFrameDuration!.inMilliseconds) {
        slowFramesCount++;
        slowFramesDuration += effectiveDuration;
      }

      framesDelay += effectiveDelay;
    }

    final spanDuration =
        spanEndTimestamp.difference(span.startTimestamp).inMilliseconds;
    final normalFramesCount =
        (spanDuration - (slowFramesDuration + frozenFramesDuration)) /
            expectedFrameDuration!.inMilliseconds;
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

    final numberOfFrames =
        (spanDuration - framesDelay) / expectedFrameDuration!.inMilliseconds;

    final estimatedFrameRate = (numberOfFrames / (spanDuration / 1000)).toInt();

    final relativeFrameDelay = framesDelay ~/ spanDuration;

    return {
      SpanFrameMetricsCollector.totalFramesKey: totalFramesCount,
      SpanFrameMetricsCollector.framesDelayKey: framesDelay,
      SpanFrameMetricsCollector.slowFramesKey: slowFramesCount,
      SpanFrameMetricsCollector.frozenFramesKey: frozenFramesCount,
      SpanFrameMetricsCollector.estimatedFrameRateKey: estimatedFrameRate,
      SpanFrameMetricsCollector.relativeFrameDelayKey: relativeFrameDelay,
    };
  }

  @override
  void clear() {
    _isTrackingPaused = true;
    _stopwatch.reset();
    exceededFrames.clear();
    activeSpans.clear();
    displayRefreshRate = null;
  }
}
