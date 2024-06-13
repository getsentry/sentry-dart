import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';

import '../sentry_flutter.dart';

// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

import 'frame_callback_handler.dart';

@internal
class SpanFrameMetricsCollector implements PerformanceContinuousCollector {
  final frames = SplayTreeMap<DateTime, int>();
  final runningSpans = <ISentrySpan>[];

  bool _isFrameTrackingPaused = true;
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
  void onSpanFinished(ISentrySpan span) {
    if (span is NoOpSentrySpan || !options.enableFramesTracking) {
      return;
    }

    captureFrameMetrics(span);

    if (runningSpans.isEmpty) {
      clear();
    } else {
      // remove irrelevant frames
    }
  }

  void captureFrameMetrics(ISentrySpan span) {
    runningSpans.removeWhere(
        (element) => element.context.spanId == span.context.spanId);

    final endTimestamp = span.endTimestamp;
    if (endTimestamp == null) {
      // todo: log
      return;
    }

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

    span.setData("frames.total", totalFramesCount);
    span.setData("frames.delay", frameDelay);
    span.setData("frames.slow", slowFrames.length);
    span.setData("frames.frozen", frozenFrames.length);

    // ignore: invalid_use_of_internal_member
    if (span is SentryTracer) {
      span.setMeasurement("frames_total", totalFramesCount);
      span.setMeasurement("frames_delay", frameDelay);
      span.setMeasurement("frames_slow", slowFrames.length);
      span.setMeasurement("frames_frozen", frozenFrames.length);
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
