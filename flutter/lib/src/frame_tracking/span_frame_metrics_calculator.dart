import 'dart:math';
import 'package:meta/meta.dart';
import 'sentry_delayed_frames_tracker.dart';

/// The duration at which we consider a frame 'frozen'
const _frozenFrameThreshold = Duration(milliseconds: 700);

@internal
class SpanFrameMetricsCalculator {
  SpanFrameMetricsCalculator(this._expectedFrameDuration);

  final Duration _expectedFrameDuration;

  /// Calculates the frame metrics based on start, end timestamps and the
  /// delayed frames metrics. If the delayed frames array is empty then
  /// only the total frames will be calculated.
  SpanFrameMetrics? calculateFrameMetrics(
      {required DateTime spanStartTimestamp,
      required DateTime spanEndTimestamp,
      required List<SentryFrameTiming> delayedFrames}) {
    final spanDuration =
        spanEndTimestamp.difference(spanStartTimestamp).inMilliseconds;

    if (delayedFrames.isEmpty) {
      return SpanFrameMetrics(
          totalFrameCount:
              (spanDuration / _expectedFrameDuration.inMilliseconds).ceil(),
          slowFrameCount: 0,
          frozenFrameCount: 0,
          framesDelay: 0);
    }

    int slowFrameCount = 0;
    int frozenFrameCount = 0;
    int slowFramesDuration = 0;
    int frozenFramesDuration = 0;
    int framesDelay = 0;

    for (final timing in delayedFrames) {
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
            max(0, frameDurationMs - _expectedFrameDuration.inMilliseconds);
      } else if (framePartiallyContainedInSpan) {
        final intersectionStart = max(frameStartMs, spanStartMs);
        final intersectionEnd = min(frameEndMs, spanEndMs);
        effectiveDuration = intersectionEnd - intersectionStart;

        final fullFrameDelay =
            max(0, frameDurationMs - _expectedFrameDuration.inMilliseconds);
        final intersectionRatio = effectiveDuration / frameDurationMs;
        effectiveDelay = (fullFrameDelay * intersectionRatio).round();
      } else if (frameStartMs > spanEndMs) {
        // Other frames will be newer than this span, as frames are ordered
        break;
      }

      if (effectiveDuration >= _frozenFrameThreshold.inMilliseconds) {
        frozenFrameCount++;
        frozenFramesDuration += effectiveDuration;
      } else if (effectiveDuration > _expectedFrameDuration.inMilliseconds) {
        slowFrameCount++;
        slowFramesDuration += effectiveDuration;
      }

      framesDelay += effectiveDelay;
    }

    final normalFramesCount =
        (spanDuration - (slowFramesDuration + frozenFramesDuration)) /
            _expectedFrameDuration.inMilliseconds;
    final totalFrameCount =
        (normalFramesCount + slowFrameCount + frozenFrameCount).ceil();

    if (totalFrameCount < 0 ||
        slowFrameCount < 0 ||
        frozenFrameCount < 0 ||
        framesDelay < 0) {
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
