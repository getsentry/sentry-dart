// TODO: maybe could be an extension
import 'dart:math';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'sentry_frame_tracker.dart';

/// The duration at which we consider a frame 'frozen'
const _frozenFrameThreshold = Duration(milliseconds: 700);

@internal
class SpanFrameMetricsCalculator {
  SpanFrameMetricsCalculator(this._logger);

  final SentryLogger _logger;

  SpanFrameMetrics? calculateFrameMetrics(
      {required DateTime spanStartTimestamp,
      required DateTime spanEndTimestamp,
      required List<SentryFrameTiming> exceededFrameTimings,
      required Duration expectedFrameDuration}) {
    final spanDuration =
        spanEndTimestamp.difference(spanStartTimestamp).inMilliseconds;
    if (exceededFrameTimings.isEmpty) {
      return SpanFrameMetrics(
          totalFrameCount:
              (spanDuration / expectedFrameDuration.inMilliseconds).ceil(),
          slowFrameCount: 0,
          frozenFrameCount: 0,
          framesDelay: 0);
    }

    int slowFrameCount = 0;
    int frozenFrameCount = 0;
    int slowFramesDuration = 0;
    int frozenFramesDuration = 0;
    int framesDelay = 0;

    for (final timing in exceededFrameTimings) {
      final frameDuration = timing.duration;
      final frameEndTimestamp = timing.endTimestamp;
      final frameStartTimestamp = timing.startTimestamp;

      final frameEndMs = frameEndTimestamp.millisecondsSinceEpoch;
      final spanStartMs = spanStartTimestamp.millisecondsSinceEpoch;
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

    final normalFramesCount =
        (spanDuration - (slowFramesDuration + frozenFramesDuration)) /
            expectedFrameDuration.inMilliseconds;
    final totalFrameCount =
        (normalFramesCount + slowFrameCount + frozenFrameCount).ceil();

    if (totalFrameCount < 0 ||
        framesDelay < 0 ||
        slowFrameCount < 0 ||
        frozenFrameCount < 0) {
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
}

@internal
class SpanFrameMetricKey {
  final String data;
  final String measurement;

  SpanFrameMetricKey._(this.data) : measurement = data.replaceAll('.', '_');

  static final totalFrames = SpanFrameMetricKey._('frames.total');
  static final slowFrames = SpanFrameMetricKey._('frames.slow');
  static final frozenFrames = SpanFrameMetricKey._('frames.frozen');
  static final framesDelay = SpanFrameMetricKey._('frames.delay');

  static final allKeys = [
    totalFrames,
    slowFrames,
    frozenFrames,
    framesDelay,
  ];
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
    final dataMap = {
      SpanFrameMetricKey.totalFrames: totalFrameCount,
      SpanFrameMetricKey.slowFrames: slowFrameCount,
      SpanFrameMetricKey.frozenFrames: frozenFrameCount,
      SpanFrameMetricKey.framesDelay: framesDelay,
    };

    // Apply data to the span
    _setData(span, dataMap);

    // If it's a root span, also apply measurements
    if (span is SentrySpan && span.isRootSpan) {
      // ignore: invalid_use_of_internal_member
      final tracer = span.tracer;

      _setData(tracer, dataMap);
      _setMeasurements(span, dataMap);
    }
  }

  void _setData(ISentrySpan span, Map<SpanFrameMetricKey, num> dataMap) {
    dataMap.forEach((metricKey, value) {
      span.setData(metricKey.data, value);
    });
  }

  void _setMeasurements(
      ISentrySpan span, Map<SpanFrameMetricKey, num> dataMap) {
    dataMap.forEach((metricKey, value) {
      span.setMeasurement(metricKey.measurement, value);
    });
  }
}
