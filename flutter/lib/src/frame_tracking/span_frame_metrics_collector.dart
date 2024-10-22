// ignore_for_file: invalid_use_of_internal_member

import 'dart:collection';
import 'package:meta/meta.dart';
import '../../sentry_flutter.dart';
import '../native/sentry_native_binding.dart';
import 'sentry_frame_tracker.dart';
import 'span_frame_metrics_calculator.dart';

@internal
class SpanFrameMetricsCollector implements PerformanceContinuousCollector {
  SpanFrameMetricsCollector(this._options, this._frameTracker,
      this._frameMetricsCalculator, this._nativeBinding);

  final SentryFlutterOptions _options;
  final SentryFrameTracker _frameTracker;
  final SentryNativeBinding? _nativeBinding;
  final SpanFrameMetricsCalculator _frameMetricsCalculator;

  /// Stores the spans that are actively being tracked.
  /// After the frames are calculated and stored in the span the span is removed from this list.
  @visibleForTesting
  final activeSpans = SplayTreeSet<ISentrySpan>(
      (a, b) => a.startTimestamp.compareTo(b.startTimestamp));

  @override
  Future<void> onSpanStarted(ISentrySpan span) async {
    return _tryCatch('onSpanFinished', () async {
      final shouldProcess = await _shouldProcess(span);
      if (!shouldProcess) {
        return;
      }

      activeSpans.add(span);
      _frameTracker.resume();
    });
  }

  @override
  Future<void> onSpanFinished(ISentrySpan span, DateTime endTimestamp) async {
    return _tryCatch('onSpanFinished', () async {
      final shouldProcess = await _shouldProcess(span);
      if (!shouldProcess) {
        return;
      }

      final startTimestamp = span.startTimestamp;
      final frameTimings = _frameTracker.getFramesIntersecting(
          startTimestamp: startTimestamp, endTimestamp: endTimestamp);
      final metrics = _frameMetricsCalculator.calculateFrameMetrics(
          spanStartTimestamp: startTimestamp,
          spanEndTimestamp: endTimestamp,
          exceededFrameTimings: frameTimings,
          expectedFrameDuration: _frameTracker.expectedFrameDuration!);
      metrics?.applyTo(span);

      activeSpans.remove(span);
      if (activeSpans.isEmpty) {
        clear();
      } else {
        _frameTracker.removeFramesBefore(activeSpans.first.startTimestamp);
      }
    });
  }

  Future<bool> _shouldProcess(ISentrySpan span) async {
    if (span is NoOpSentrySpan || !_options.enableFramesTracking) {
      return false;
    }
    return _ensureExpectedFrameDurationInitialized();
  }

  /// Returns true if expected frame duration is initialized and false if failed.
  Future<bool> _ensureExpectedFrameDurationInitialized() async {
    if (_frameTracker.expectedFrameDuration != null) return true;
    return _initializeExpectedFrameDuration();
  }

  Future<bool> _initializeExpectedFrameDuration() async {
    final displayRefreshRate = await _nativeBinding?.displayRefreshRate();
    if (displayRefreshRate == null || displayRefreshRate <= 0) {
      _options.logger(SentryLevel.debug,
          'Could not retrieve a valid display refresh rate.');
      return false;
    }
    final expectedFrameDuration =
        Duration(milliseconds: ((1 / displayRefreshRate) * 1000).toInt());
    _frameTracker.setExpectedFrameDuration(expectedFrameDuration);
    return true;
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
