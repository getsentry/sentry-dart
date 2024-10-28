// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';
import '../../sentry_flutter.dart';
import 'sentry_delayed_frames_tracker.dart';

/// Collects frames from [SentryDelayedFramesTracker], calculates the metrics
/// and attaches them to spans.
@internal
class SpanFrameMetricsCollector implements PerformanceContinuousCollector {
  SpanFrameMetricsCollector(this._options, this._frameTracker);

  final SentryFlutterOptions _options;
  final SentryDelayedFramesTracker _frameTracker;

  /// Stores the spans that are actively being tracked.
  /// After the frames are calculated and stored in the span the span is removed from this list.
  @visibleForTesting
  final List<ISentrySpan> activeSpans = [];

  @override
  Future<void> onSpanStarted(ISentrySpan span) async {
    return _tryCatch('onSpanFinished', () async {
      if (span is NoOpSentrySpan) {
        return;
      }

      activeSpans.add(span);
      _frameTracker.resume();
    });
  }

  @override
  Future<void> onSpanFinished(ISentrySpan span, DateTime endTimestamp) async {
    return _tryCatch('onSpanFinished', () async {
      if (span is NoOpSentrySpan) {
        return;
      }

      final startTimestamp = span.startTimestamp;
      final metrics = _frameTracker.getFrameMetrics(
          spanStartTimestamp: startTimestamp, spanEndTimestamp: endTimestamp);
      metrics?.applyTo(span);

      activeSpans.remove(span);
      if (activeSpans.isEmpty) {
        clear();
      }
    });
  }

  // TODO: there's already a similar implementation: [SentryNativeSafeInvoker]
  // let's try to reuse it at some point
  Future<void> _tryCatch(String methodName, Future<void> Function() fn) async {
    try {
      return fn();
    } catch (exception, stackTrace) {
      _options.logger(
        SentryLevel.error,
        'SpanFrameMetricsCollector $methodName failed',
        exception: exception,
        stackTrace: stackTrace,
      );
      clear();
    }
  }

  @override
  void clear() {
    _frameTracker.clear();
    activeSpans.clear();
    // we don't need to clear the expected frame duration as that realistically
    // won't change throughout the application's lifecycle
  }
}
