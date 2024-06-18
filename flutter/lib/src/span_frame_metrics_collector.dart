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

  /// Stores the DateTime when a frame happened and the duration of that frame in milliseconds.
  final frames = SplayTreeMap<DateTime, int>();

  /// Stores the running spans that are being tracked.
  /// After the frames are computed and stored in the span the span is removed from this list.
  final runningSpans = <ISentrySpan>[];

  bool get isFrameTrackingPaused => _isFrameTrackingPaused;
  bool _isFrameTrackingPaused = true;

  bool get isFrameTrackingRegistered => _isFrameTrackingRegistered;
  bool _isFrameTrackingRegistered = false;

  final _stopwatch = Stopwatch();

  SpanFrameMetricsCollector(this.options,
      {FrameCallbackHandler? frameCallbackHandler, SentryNative? native})
      : _frameCallbackHandler =
            frameCallbackHandler ?? DefaultFrameCallbackHandler(),
        _native = native ?? SentryFlutter.native;

  @override
  void onSpanStarted(ISentrySpan span) {
    if (span is NoOpSentrySpan || !options.enableFramesTracking) {
      return;
    }

    runningSpans.add(span);
    startFrameTracking();
  }

  @override
  Future<void> onSpanFinished(ISentrySpan span, DateTime endTimestamp) async {
    if (span is NoOpSentrySpan || !options.enableFramesTracking) {
      return Future.value();
    }

    await recordSpanFrameMetrics(span, endTimestamp);

    if (runningSpans.isEmpty) {
      clear();
    } else {
      final oldestSpan = runningSpans.first;
      frames.removeWhere((key, value) {
        return key.isBefore(oldestSpan.startTimestamp);
      });
    }
  }

  /// Calls [WidgetsBinding.instance.addPersistentFrameCallback] which cannot be unregistered
  /// and exists for the duration of the application's lifetime.
  ///
  /// Stopping the frame tracking means setting `isFrameTrackingPaused = true`
  /// to prevent actions being done when the frame callback is triggered.
  void startFrameTracking() {
    _isFrameTrackingPaused = false;

    if (!_isFrameTrackingRegistered) {
      _frameCallbackHandler?.addPersistentFrameCallback(frameCallback);
      _isFrameTrackingRegistered = true;
    }
  }

  void frameCallback(Duration duration) async {
    if (_isFrameTrackingPaused) {
      return;
    }

    if (_stopwatch.elapsedMilliseconds == 0) {
      _stopwatch.start();
    }

    await _frameCallbackHandler?.endOfFrame;
    _stopwatch.stop();

    // ignore: invalid_use_of_internal_member
    frames[getUtcDateTime()] = _stopwatch.elapsedMilliseconds;

    _stopwatch.reset();
    if (_frameCallbackHandler?.hasScheduledFrame == true) {
      _stopwatch.start();
    }
  }

  Future<void> recordSpanFrameMetrics(
      ISentrySpan span, DateTime endTimestamp) async {
    final displayRefreshRate = await _native?.displayRefreshRate();
    if (displayRefreshRate == null) {
      options.logger(SentryLevel.warning,
          'Display refresh rate is not available. Dropping the frame metrics');
      clear();
      return;
    }

    runningSpans.removeWhere(
        (element) => element.context.spanId == span.context.spanId);

    final frameMetrics =
        computeFrameMetrics(span, endTimestamp, displayRefreshRate);

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

  Map<String, int> computeFrameMetrics(
      ISentrySpan span, DateTime endTimestamp, int displayRefreshRate) {
    final expectedFrameDuration = ((1 / displayRefreshRate) * 1000).toInt();

    final durations = frames.keys
        .takeWhile((value) =>
            value.isBefore(endTimestamp) && value.isAfter(span.startTimestamp))
        .toList();

    if (durations.isEmpty) {
      options.logger(
          SentryLevel.info, 'No frame durations available in frame tracker.');
      return {};
    }

    final slowFrames = durations.where((element) {
      final frame = frames[element];
      return frame != null && frame > expectedFrameDuration && frame < 700;
    });
    final slowFramesDuration =
        slowFrames.fold<int>(0, (previousValue, element) {
      final frameDuration = frames[element] ?? 0;
      return previousValue + frameDuration;
    });

    final frozenFrames = durations.where((element) {
      final frame = frames[element];
      return frame != null && frame > 700;
    });
    final frozenFramesDuration =
        frozenFrames.fold<int>(0, (previousValue, element) {
      final frameDuration = frames[element] ?? 0;
      return previousValue + frameDuration;
    });

    final frameDelay = durations.fold<int>(0, (previousValue, element) {
      final frameDuration = frames[element];
      if (frameDuration != null && frameDuration > expectedFrameDuration) {
        return previousValue + (frameDuration - expectedFrameDuration);
      }
      return previousValue;
    });

    final spanDuration =
        endTimestamp.difference(span.startTimestamp).inMilliseconds;
    final totalFramesCount =
        ((spanDuration - (slowFramesDuration + frozenFramesDuration)) /
                expectedFrameDuration) +
            slowFrames.length +
            frozenFrames.length;

    if (totalFramesCount < 0 || frameDelay < 0) {
      options.logger(SentryLevel.warning,
          'Negative frame metrics detected. Dropping the frame metrics');
      return {};
    }

    return {
      "frames.total": totalFramesCount.toInt(),
      "frames.delay": frameDelay,
      "frames.slow": slowFrames.length,
      "frames.frozen": frozenFrames.length,
    };
  }

  @override
  void clear() {
    _isFrameTrackingPaused = true;
    frames.clear();
    runningSpans.clear();
  }
}
