// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../utils/internal_logger.dart';
import 'sentry_delayed_frames_tracker.dart';

/// Collects frame metrics for both legacy and streaming spans via
/// [InstrumentationSpan] wrappers.
@internal
class SpanFrameMetricsCollector {
  SpanFrameMetricsCollector(
    this._frameTracker, {
    required void Function() resumeFrameTracking,
    required void Function() pauseFrameTracking,
  })  : _resumeFrameTracking = resumeFrameTracking,
        _pauseFrameTracking = pauseFrameTracking;

  final SentryDelayedFramesTracker _frameTracker;
  final void Function() _resumeFrameTracking;
  final void Function() _pauseFrameTracking;

  /// Spans currently being tracked. Frame tracking pauses when empty.
  @visibleForTesting
  final List<InstrumentationSpan> activeSpans = [];

  Future<void> onSpanStarted(InstrumentationSpan span) async {
    return _tryCatch('onSpanStarted', () async {
      if (span.isNoop) {
        return;
      }

      activeSpans.add(span);
      _resumeFrameTracking();
    });
  }

  Future<void> onSpanFinished(
    InstrumentationSpan span,
    DateTime endTimestamp,
  ) async {
    return _tryCatch('onSpanFinished', () async {
      if (span.isNoop) {
        return;
      }

      final startTimestamp = span.startTimestamp;
      final metrics = _frameTracker.getFrameMetrics(
        spanStartTimestamp: startTimestamp,
        spanEndTimestamp: endTimestamp,
      );

      if (metrics != null) {
        _applyFrameMetrics(span, metrics);
      }

      activeSpans.remove(span);
      if (activeSpans.isEmpty) {
        clear();
      } else {
        _frameTracker.removeIrrelevantFrames(activeSpans.first.startTimestamp);
      }
    });
  }

  /// Applies frame metrics based on wrapper type.
  void _applyFrameMetrics(InstrumentationSpan span, SpanFrameMetrics metrics) {
    if (span is LegacyInstrumentationSpan) {
      metrics.applyTo(span.spanReference);
    } else if (span is StreamingInstrumentationSpan) {
      final spanRef = span.spanReference;
      if (spanRef is RecordingSentrySpanV2) {
        final attributes = <String, SentryAttribute>{};
        attributes[SemanticAttributesConstants.framesTotal] =
            SentryAttribute.int(metrics.totalFrameCount);
        attributes[SemanticAttributesConstants.framesSlow] =
            SentryAttribute.int(metrics.slowFrameCount);
        attributes[SemanticAttributesConstants.framesFrozen] =
            SentryAttribute.int(metrics.frozenFrameCount);
        attributes[SemanticAttributesConstants.framesDelay] =
            SentryAttribute.int(metrics.framesDelay);
        spanRef.setAttributesIfAbsent(attributes);
      }
    } else {
      internalLogger.warning(
        'Unknown InstrumentationSpan type: ${span.runtimeType}',
      );
    }
  }

  Future<void> _tryCatch(String methodName, Future<void> Function() fn) async {
    try {
      return await fn();
    } catch (exception, stackTrace) {
      internalLogger.error(
        'SpanFrameMetricsCollector $methodName failed',
        error: exception,
        stackTrace: stackTrace,
      );
      clear();
    }
  }

  void clear() {
    _pauseFrameTracking();
    _frameTracker.clear();
    activeSpans.clear();
  }
}
