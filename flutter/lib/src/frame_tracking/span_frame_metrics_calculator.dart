// TODO: maybe could be an extension
import 'dart:math';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'frame_tracker.dart';

@internal
class SpanFrameMetricsCalculator {
  SpanFrameMetricsCalculator({SentryOptions? options})
      // ignore: invalid_use_of_internal_member
      : _options = options ?? Sentry.currentHub.options;

  final _frozenFrameThreshold = Duration(milliseconds: 700);
  final SentryOptions _options;

  SpanFrameMetrics? calculateFor(ISentrySpan span,
      {required List<SentryFrameTiming> frameTimings,
      required Duration expectedFrameDuration}) {
    if (frameTimings.isEmpty) {
      _options.logger(
          SentryLevel.info, 'No frame timings available in frame tracker.');
      return null;
    }

    int slowFrameCount = 0;
    int frozenFrameCount = 0;
    int slowFramesDuration = 0;
    int frozenFramesDuration = 0;
    int framesDelay = 0;
    final spanEndTimestamp = span.endTimestamp;

    if (spanEndTimestamp == null) {
      return null;
    }

    for (final timing in frameTimings) {
      final frameDuration = timing.duration;
      final frameEndTimestamp = timing.endTimestamp;
      final frameStartTimestamp = timing.startTimestamp;

      final frameEndMs = frameEndTimestamp.millisecondsSinceEpoch;
      final spanStartMs = span.startTimestamp.millisecondsSinceEpoch;
      final spanEndMs = spanEndTimestamp.millisecondsSinceEpoch;
      final frameStartMs = frameStartTimestamp.millisecondsSinceEpoch;
      final frameDurationMs = frameDuration.inMilliseconds;

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
        effectiveDuration = frameDurationMs;
        effectiveDelay =
            max(0, frameDurationMs - expectedFrameDuration.inMilliseconds);
      } else if (framePartiallyContainedInSpan) {
        final intersectionStart = max(frameStartMs, spanStartMs);
        final intersectionEnd = min(frameEndMs, spanEndMs);
        effectiveDuration = intersectionEnd - intersectionStart;

        final fullFrameDelay =
            max(0, frameDurationMs - expectedFrameDuration.inMilliseconds);
        final intersectionRatio = effectiveDuration / frameDurationMs;
        effectiveDelay = (fullFrameDelay * intersectionRatio).round();
      } else if (frameStartMs > spanEndMs) {
        // Other frames will be newer than this span, as frames are ordered
        break;
      }

      if (effectiveDuration >= _frozenFrameThreshold.inMilliseconds) {
        frozenFrameCount++;
        frozenFramesDuration += effectiveDuration;
      } else if (effectiveDuration > expectedFrameDuration.inMilliseconds) {
        slowFrameCount++;
        slowFramesDuration += effectiveDuration;
      }

      framesDelay += effectiveDelay;
    }

    final spanDuration =
        spanEndTimestamp.difference(span.startTimestamp).inMilliseconds;
    final normalFramesCount =
        (spanDuration - (slowFramesDuration + frozenFramesDuration)) /
            expectedFrameDuration.inMilliseconds;
    final totalFrameCount =
        (normalFramesCount + slowFrameCount + frozenFrameCount).ceil();

    final metrics = SpanFrameMetrics(
        totalFrameCount: totalFrameCount,
        slowFrameCount: slowFrameCount,
        frozenFrameCount: frozenFrameCount,
        framesDelay: framesDelay);

    if (!metrics.isValid()) {
      return null;
    }

    return metrics;
  }
}

@internal
class SpanFrameMetrics {
  final int totalFrameCount;
  final int slowFrameCount;
  final int frozenFrameCount;
  final int framesDelay;

  bool isValid() {
    if (totalFrameCount < 0 ||
        framesDelay < 0 ||
        slowFrameCount < 0 ||
        frozenFrameCount < 0) {
      return false;
    }

    if (totalFrameCount < slowFrameCount ||
        totalFrameCount < frozenFrameCount) {
      return false;
    }

    return true;
  }

  SpanFrameMetrics({
    required this.totalFrameCount,
    required this.slowFrameCount,
    required this.frozenFrameCount,
    required this.framesDelay,
  });

  void applyTo(ISentrySpan span) {
    // Apply data to the span
    span.setData('frames.total', totalFrameCount);
    span.setData('frames.slow', slowFrameCount);
    span.setData('frames.frozen', frozenFrameCount);
    span.setData('frames.delay', framesDelay);

    // If it's a root span, also apply measurements
    if (span is SentrySpan && span.isRootSpan) {
      // ignore: invalid_use_of_internal_member
      final tracer = span.tracer;

      tracer.setData('frames.total', totalFrameCount);
      tracer.setData('frames.slow', slowFrameCount);
      tracer.setData('frames.frozen', frozenFrameCount);
      tracer.setData('frames.delay', framesDelay);

      // Set measurements
      span.setMeasurement('frames_total', totalFrameCount);
      span.setMeasurement('frames_slow', slowFrameCount);
      span.setMeasurement('frames_frozen', frozenFrameCount);
      span.setMeasurement('frames_delay', framesDelay);
    }
  }
}
