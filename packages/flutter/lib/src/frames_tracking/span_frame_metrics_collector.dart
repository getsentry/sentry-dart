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

  /// Frame tracking pauses when empty.
  final List<InstrumentationSpan> _activeSpans = [];

  List<InstrumentationSpan> get activeSpans => List.unmodifiable(_activeSpans);

  Future<void> startTracking(InstrumentationSpan span) async {
    return _tryCatch('onSpanStarted', () async {
      if (!span.isRecording) {
        return;
      }

      _activeSpans.add(span);
      _resumeFrameTracking();
    });
  }

  Future<void> finishTracking(
    InstrumentationSpan span,
    DateTime endTimestamp,
  ) async {
    return _tryCatch('onSpanFinished', () async {
      if (!span.isRecording) {
        return;
      }

      final startTimestamp = span.startTimestamp;
      final metrics = _frameTracker.getFrameMetrics(
        spanStartTimestamp: startTimestamp,
        spanEndTimestamp: endTimestamp,
      );

      if (metrics != null) {
        span.applyFrameMetrics(metrics);
      }

      _activeSpans.remove(span);
      if (_activeSpans.isEmpty) {
        clear();
      } else {
        _frameTracker.removeIrrelevantFrames(_activeSpans.first.startTimestamp);
      }
    });
  }

  void removeFromActiveSpans(InstrumentationSpan span) {
    _activeSpans.remove(span);
    if (_activeSpans.isEmpty) {
      clear();
    } else {
      _frameTracker.removeIrrelevantFrames(_activeSpans.first.startTimestamp);
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
    _activeSpans.clear();
  }
}

extension _InstrumentationSpanFrameMetrics on InstrumentationSpan {
  void applyFrameMetrics(SpanFrameMetrics metrics) {
    if (this is LegacyInstrumentationSpan) {
      metrics.applyTo((this as LegacyInstrumentationSpan).spanReference);
    } else if (this is StreamingInstrumentationSpan) {
      final spanRef = (this as StreamingInstrumentationSpan).spanReference;
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
        'Unknown InstrumentationSpan type: $runtimeType',
      );
    }
  }
}
