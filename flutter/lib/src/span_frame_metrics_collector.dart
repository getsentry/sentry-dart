import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';

import '../sentry_flutter.dart';

// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

@internal
class SpanFrameMetricsCollector implements PerformanceContinuousCollector {
  final frames = SplayTreeMap<DateTime, int>();
  final runningSpans = <ISentrySpan>[];
  bool lockFrameTracking = false;
  final _stopwatch = Stopwatch();

  final SentryFlutterOptions options;

  bool frameCollectorIsRunning = false;

  SpanFrameMetricsCollector(this.options);

  @override
  void onSpanStarted(ISentrySpan span) {
    if (!frameCollectorIsRunning) {
      startFrameCollector();
      frameCollectorIsRunning = true;
    }

    // if enabled
    if (span is NoOpSentrySpan || !options.enableFramesTracking) {
      return;
    }

    runningSpans.add(span);
    lockFrameTracking = true;
  }

  @override
  void onSpanFinished(ISentrySpan span) {
    if (span is NoOpSentrySpan || !options.enableFramesTracking) {
      return;
    }

    captureFrameMetrics(span);

    print('-------');
    runningSpans.forEach((element) {
      print('running span: ${element.context.spanId}');
    });

    if (runningSpans.isEmpty) {
      clear();
    } else {
      // remove irrelevant frames
    }
  }

  void captureFrameMetrics(ISentrySpan span) {
    runningSpans.removeWhere(
        (element) => element.context.spanId == span.context.spanId);

    final endTimestamp = span.endTimestamp ?? options.clock();

    final durations = frames.keys
        .takeWhile((value) =>
            value.isBefore(endTimestamp) && value.isAfter(span.startTimestamp))
        .toList();
    final slowFrames = durations.where((element) => frames[element]! > 16);
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
    final spanDuration =
        endTimestamp.difference(span.startTimestamp).inMilliseconds;
    final totalFramesCount =
        (spanDuration - (slowFramesDuration + frozenFramesDuration)) / 16;
    // Frame delay = max(0, frame duration - expected frame duration) for each frame and count the total.
    final frameDelay = durations.fold<int>(0, (previousValue, element) {
      final frameDuration = frames[element];
      if (frameDuration != null && frameDuration > 16) {
        return previousValue + (frameDuration - 16);
      }
      return previousValue;
    });

    span.setData("frames.total", totalFramesCount);
    span.setData("frames.delay", frameDelay);
    span.setData("frames.slow", slowFrames.length);
    span.setData("frames.frozen", frozenFrames.length);

    if (span is SentrySpan) {
      print("description: ${span.context.description}");
      print("data: ${span.data}");
    }

    // ignore: invalid_use_of_internal_member
    if (span is SentryTracer) {
      span.setMeasurement("frames_total", totalFramesCount);
      span.setMeasurement("frames_delay", frameDelay);
      span.setMeasurement("frames_slow", slowFrames.length);
      span.setMeasurement("frames_frozen", frozenFrames.length);
    }
  }

  void frameCallback(Duration timeStamp) async {
    if (!lockFrameTracking) {
      return;
    }

    if (_stopwatch.elapsedMilliseconds == 0) {
      _stopwatch.start();
    }
    await WidgetsBinding.instance.endOfFrame;
    _stopwatch.stop();
    final elapsedMilliseconds = _stopwatch.elapsedMilliseconds;
    _stopwatch.reset();
    if (WidgetsBinding.instance.hasScheduledFrame) {
      _stopwatch.start();
    }

    print('Frame elapsed: $elapsedMilliseconds');
    frames[DateTime.now()] = elapsedMilliseconds;
  }

  /// Calls [WidgetsBinding.instance.addPersistentFrameCallback] which cannot be unregistered.
  ///
  /// Stopping the frame tracking means setting a flag to prevent actions being done
  /// when the frame callback is triggered.
  void startFrameCollector() {
    WidgetsBinding.instance.addPersistentFrameCallback(frameCallback);
  }

  @override
  void clear() {
    lockFrameTracking = false;
    frames.clear();
    runningSpans.clear();
  }
}
