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
    required this._resumeFrameTracking,
    required this._pauseFrameTracking,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// When frame tracking last resumed. No frame was observed before it.
  DateTime? _trackingSince;

  final SentryDelayedFramesTracker _frameTracker;
  final void Function() _resumeFrameTracking;
  final void Function() _pauseFrameTracking;

  /// Frame tracking pauses when empty.
  final List<InstrumentationSpan> _activeSpans = [];

  @visibleForTesting
  List<InstrumentationSpan> get activeSpans => _activeSpans;

  Future<void> startTracking(InstrumentationSpan span) async {
    return _tryCatch('onSpanStarted', () async {
      if (!span.isRecording) {
        return;
      }

      if (_activeSpans.isEmpty) {
        _trackingSince = _clock();
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

      // A span created with past timestamps can end before frame tracking
      // resumed. No frame was observed for it, so it gets no frame metrics.
      final trackingSince = _trackingSince;
      if (trackingSince != null && !endTimestamp.isAfter(trackingSince)) {
        removeFromActiveSpans(span);
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

      removeFromActiveSpans(span);
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
    _trackingSince = null;
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
            SentryAttribute.double(metrics.framesDelay);
        spanRef.setAttributesIfAbsent(attributes);
      }
    } else {
      internalLogger.warning('Unknown InstrumentationSpan type: $runtimeType');
    }
  }
}
