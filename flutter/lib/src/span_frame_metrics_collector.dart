import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';

import '../sentry_flutter.dart';

import 'frame_callback_handler.dart';

@internal
class SpanFrameMetricsCollector implements PerformanceContinuousCollector {
  final frames = SplayTreeMap<DateTime, int>();
  final runningSpans = <ISentrySpan>[];

  bool get isFrameTrackingPaused => _isFrameTrackingPaused;
  bool _isFrameTrackingPaused = true;

  bool get isFrameTrackingRegistered => _isFrameTrackingRegistered;
  bool _isFrameTrackingRegistered = false;

  final _stopwatch = Stopwatch();

  final SentryFlutterOptions options;

  final FrameCallbackHandler? _frameCallbackHandler;

  SpanFrameMetricsCollector(this.options,
      {FrameCallbackHandler? frameCallbackHandler})
      : _frameCallbackHandler =
            frameCallbackHandler ?? DefaultFrameCallbackHandler();

  @override
  void onSpanStarted(ISentrySpan span) {
    if (span is NoOpSentrySpan || !options.enableFramesTracking) {
      return;
    }

    runningSpans.add(span);
    startFrameCollector();
  }

  @override
  void onSpanFinished(ISentrySpan span, DateTime endTimestamp) {
    print('hello: ${span.context.description}');
    print(span is SentrySpan && span.isRootSpan);
    print(span is NoOpSentrySpan);
    if (span is NoOpSentrySpan || !options.enableFramesTracking) {
      return;
    }
    print('hello after: ${span.context.description}');

    captureFrameMetrics(span, endTimestamp);

    if (runningSpans.isEmpty) {
      clear();
    } else {
      final oldestSpan = runningSpans.first;
      frames.removeWhere((key, value) {
        return key.isBefore(oldestSpan.startTimestamp);
      });
    }
  }

  Map<String, int> calculateFrameMetrics(
      ISentrySpan span, DateTime endTimestamp) {
    final durations = frames.keys
        .takeWhile((value) =>
            value.isBefore(endTimestamp) && value.isAfter(span.startTimestamp))
        .toList();

    final slowFrames = durations
        .where((element) => frames[element]! > 16 && frames[element]! < 700);
    final slowFramesDuration =
        slowFrames.fold<int>(0, (previousValue, element) {
      final frameDuration = frames[element] ?? 0;
      return previousValue + frameDuration;
    });

    final frozenFrames =
        durations.where((element) => frames[element]! > 700).toList();
    final frozenFramesDuration =
        frozenFrames.fold<int>(0, (previousValue, element) {
      final frameDuration = frames[element] ?? 0;
      return previousValue + frameDuration;
    });

    final frameDelay = durations.fold<int>(0, (previousValue, element) {
      final frameDuration = frames[element];
      if (frameDuration != null && frameDuration > 16) {
        return previousValue + (frameDuration - 16);
      }
      return previousValue;
    });

    final spanDuration =
        endTimestamp.difference(span.startTimestamp).inMilliseconds;
    final totalFramesCount =
        ((spanDuration - (slowFramesDuration + frozenFramesDuration)) / 16) +
            slowFrames.length +
            frozenFrames.length;

    if (totalFramesCount < 0 || frameDelay < 0) {
      // todo: log
      return {};
    }

    return {
      "frames.total": totalFramesCount.toInt(),
      "frames.delay": frameDelay,
      "frames.slow": slowFrames.length,
      "frames.frozen": frozenFrames.length,
    };
  }

  void captureFrameMetrics(ISentrySpan span, DateTime endTimestamp) {
    runningSpans.removeWhere(
        (element) => element.context.spanId == span.context.spanId);

    final frameMetrics = calculateFrameMetrics(span, endTimestamp);
    frameMetrics.forEach((key, value) {
      span.setData(key, value);
    });

    print('is sentryspan: ${span is SentrySpan} ${span.context.description}');
    print('is root span: ${span is SentrySpan && span.isRootSpan}');
    if (span is SentrySpan && span.isRootSpan) {
      frameMetrics.forEach((key, value) {
        span.setMeasurement(key.replaceAll('.', '_'), value);
      });
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
    final elapsedMilliseconds = _stopwatch.elapsedMilliseconds;
    _stopwatch.reset();

    if (_frameCallbackHandler!.hasScheduledFrame) {
      _stopwatch.start();
    }

    // ignore: invalid_use_of_internal_member
    frames[getUtcDateTime()] = elapsedMilliseconds;
  }

  /// Calls [WidgetsBinding.instance.addPersistentFrameCallback] which cannot be unregistered
  /// and exists for the duration of the application's lifetime.
  ///
  /// Stopping the frame tracking means setting `isFrameTrackingPaused = true`
  /// to prevent actions being done when the frame callback is triggered.
  void startFrameCollector() {
    _isFrameTrackingPaused = false;

    if (!_isFrameTrackingRegistered) {
      _frameCallbackHandler?.addPersistentFrameCallback(frameCallback);
      _isFrameTrackingRegistered = true;
    }
  }

  @override
  void clear() {
    _isFrameTrackingPaused = true;
    frames.clear();
    runningSpans.clear();
  }
}
