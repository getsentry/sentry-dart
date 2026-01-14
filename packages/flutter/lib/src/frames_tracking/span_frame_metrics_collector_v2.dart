// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../utils/internal_logger.dart';
import 'sentry_delayed_frames_tracker.dart';

/// Collects frames from [SentryDelayedFramesTracker], calculates the metrics
/// and attaches them to spans.
@internal
class SpanFrameMetricsCollectorV2 implements PerformanceContinuousCollectorV2 {
  SpanFrameMetricsCollectorV2(
    this._frameTracker, {
    required void Function() resumeFrameTracking,
    required void Function() pauseFrameTracking,
  })  : _resumeFrameTracking = resumeFrameTracking,
        _pauseFrameTracking = pauseFrameTracking;

  final SentryDelayedFramesTracker _frameTracker;
  final void Function() _resumeFrameTracking;
  final void Function() _pauseFrameTracking;

  /// Stores the spans that are actively being tracked.
  /// After the frames are calculated and stored in the span the span is removed from this list.
  @visibleForTesting
  final List<SentrySpanV2> activeSpans = [];

  @override
  Future<void> onSpanStarted(SentrySpanV2 span) async {
    return _tryCatch('onSpanStarted', () async {
      if (span is NoOpSentrySpan) {
        return;
      }

      activeSpans.add(span);
      _resumeFrameTracking();
    });
  }

  @override
  Future<void> onSpanFinished(SentrySpanV2 span, DateTime endTimestamp) async {
    return _tryCatch('onSpanFinished', () async {
      if (span is NoOpSentrySpan) {
        return;
      }

      final startTimestamp = span.startTimestamp;
      final metrics = _frameTracker.getFrameMetrics(
          spanStartTimestamp: startTimestamp, spanEndTimestamp: endTimestamp);

      if (metrics != null) {
        span.setAttribute(SemanticAttributesConstants.framesTotal,
            SentryAttribute.int(metrics.totalFrameCount));
        span.setAttribute(SemanticAttributesConstants.framesSlow,
            SentryAttribute.int(metrics.slowFrameCount));
        span.setAttribute(SemanticAttributesConstants.framesFrozen,
            SentryAttribute.int(metrics.frozenFrameCount));
        span.setAttribute(SemanticAttributesConstants.framesDelay,
            SentryAttribute.int(metrics.framesDelay));
      }

      activeSpans.remove(span);
      if (activeSpans.isEmpty) {
        clear();
      } else {
        _frameTracker.removeIrrelevantFrames(activeSpans.first.startTimestamp);
      }
    });
  }

  Future<void> _tryCatch(String methodName, Future<void> Function() fn) async {
    try {
      return fn();
    } catch (exception, stackTrace) {
      internalLogger.error(
        'SpanV2FrameMetricsCollector $methodName failed',
        error: exception,
        stackTrace: stackTrace,
      );
      clear();
    }
  }

  @override
  void clear() {
    _pauseFrameTracking();
    _frameTracker.clear();
    activeSpans.clear();
    // we don't need to clear the expected frame duration as that realistically
    // won't change throughout the application's lifecycle
  }
}
