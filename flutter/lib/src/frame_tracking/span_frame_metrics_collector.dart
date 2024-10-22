// ignore_for_file: invalid_use_of_internal_member

import 'dart:collection';

import 'package:meta/meta.dart';
import '../../sentry_flutter.dart';
import '../native/sentry_native_binding.dart';
import 'span_frame_metrics_calculator.dart';

@internal
class SpanFrameMetricsCollector implements PerformanceContinuousCollector {
  SpanFrameMetricsCollector(this._options,
      {SpanFrameTracker? frameTracker,
      SpanFrameMetricsCalculator? frameMetricsCalculator,
      SentryNativeBinding? nativeBinding})
      : _frameTracker = frameTracker ?? SpanFrameTracker(),
        _frameMetricsCalculator = frameMetricsCalculator ??
            SpanFrameMetricsCalculator(_options.logger),
        _nativeBinding = nativeBinding ?? SentryFlutter.native;

  final SentryFlutterOptions _options;
  final SpanFrameTracker _frameTracker;
  final SentryNativeBinding? _nativeBinding;
  final SpanFrameMetricsCalculator _frameMetricsCalculator;
  Duration? _expectedFrameDuration;

  /// Stores the spans that are actively being tracked.
  /// After the frames are calculated and stored in the span the span is removed from this list.
  @visibleForTesting
  final activeSpans = SplayTreeSet<ISentrySpan>(
      (a, b) => a.startTimestamp.compareTo(b.startTimestamp));

  @override
  Future<void> onSpanStarted(ISentrySpan span) async {
    if (!_shouldProcess(span)) {
      return;
    }

    if (_expectedFrameDuration == null) {
      final initialized = await _tryInitializeExpectedFrameDuration();
      if (initialized) {
        _frameTracker._updateExpectedFrameDuration(_expectedFrameDuration!);
      } else {
        return;
      }
    }

    _frameTracker._resume();
  }

  @override
  Future<void> onSpanFinished(ISentrySpan span, DateTime endTimestamp) async {
    _frameTracker._pause();

    if (!_shouldProcess(span)) {
      return;
    }

    final metrics = _frameMetricsCalculator.calculateFor(span,
        frameTimings: _frameTracker.exceededFrames,
        expectedFrameDuration: _expectedFrameDuration!);
    metrics?.applyTo(span);

    activeSpans.remove(span);
    if (activeSpans.isEmpty) {
      clear();
    } else {
      _frameTracker.removeFramesBefore(activeSpans.first.startTimestamp);
    }
  }

  bool _shouldProcess(ISentrySpan span) {
    if (span is NoOpSentrySpan || !_options.enableFramesTracking) {
      return false;
    }
    return true;
  }

  /// Returns true if initializing expected frame duration succeeded and false if failed.
  Future<bool> _tryInitializeExpectedFrameDuration() async {
    // Attempt to fetch the display refresh rate
    final displayRefreshRate = await _nativeBinding?.displayRefreshRate();
    if (displayRefreshRate == null || displayRefreshRate <= 0) {
      _options.logger(
        SentryLevel.debug,
        'Could not retrieve a valid display refresh rate.',
      );
      return false;
    }

    // Calculate and cache the expected frame duration
    _expectedFrameDuration = Duration(
      microseconds: (1000000 / displayRefreshRate).round(),
    );

    return true;
  }

  @override
  void clear() {
    _frameTracker.clear();
    activeSpans.clear();
    // we don't need to clear the expected frame duration as that realistically
    // won't change throughout the application's lifecycle
  }
}

/// Singleton of a per-span frame tracker.
/// This is used in [FrameTrackingBindingMixin] to gather the build duration of
/// individual frames. The frame tracking is controlled by [SpanFrameMetricsCollector].
@internal
class SpanFrameTracker {
  SpanFrameTracker._privateConstructor(this._options);

  static SpanFrameTracker? _instance;

  factory SpanFrameTracker({SentryFlutterOptions? options}) {
    _instance ??= SpanFrameTracker._privateConstructor(
        options ?? Sentry.currentHub.options as SentryFlutterOptions);
    return _instance!;
  }

  /// A list of frame timings for frames that exceeded performance thresholds,
  /// classified as either slow or frozen based on their duration.
  ///
  /// These frames are collected during active spans.
  List<SentryFrameTiming> get exceededFrames =>
      List.unmodifiable(_exceededFrames);
  final List<SentryFrameTiming> _exceededFrames = [];

  final SentryFlutterOptions _options;
  DateTime? _currentFrameStartTimestamp;
  Duration? _expectedFrameDuration;

  /// Indicates whether the frame tracker is active.
  /// Tracking needs to be enabled externally such as [SpanFrameMetricsCollector].
  bool _isTrackingActive = false;

  void _updateExpectedFrameDuration(Duration expectedFrameDuration) {
    _expectedFrameDuration = expectedFrameDuration;
  }

  @pragma('vm:prefer-inline')
  void startFrame() {
    if (!_isTrackingActive || !_options.enableFramesTracking) {
      return;
    }

    _currentFrameStartTimestamp = _options.clock();
  }

  @pragma('vm:prefer-inline')
  void endFrame() {
    if (!_isTrackingActive ||
        !_options.enableFramesTracking ||
        _currentFrameStartTimestamp == null ||
        _expectedFrameDuration == null) {
      return;
    }

    final startTimestamp = _currentFrameStartTimestamp!;
    final endTimestamp = _options.clock();
    final frameTiming = SentryFrameTiming(startTimestamp, endTimestamp);
    print('frame duration: ${frameTiming.duration}');
    if (frameTiming.duration > _expectedFrameDuration!) {
      _exceededFrames.add(frameTiming);
    }
    _currentFrameStartTimestamp = null;
  }

  /// Pauses frame tracking.
  /// Controlled by [SpanFrameMetricsCollector].
  void _pause() {
    _isTrackingActive = false;
    _currentFrameStartTimestamp = null; // Reset any ongoing frame
  }

  /// Resumes frame tracking.
  /// Controlled by [SpanFrameMetricsCollector].
  void _resume() {
    _isTrackingActive = true;
  }

  /// Removes frames whose endTimestamp is before [time].
  void removeFramesBefore(DateTime time) {
    if (_exceededFrames.isEmpty) return;
    _exceededFrames.removeWhere((frame) => frame.endTimestamp.isBefore(time));
  }

  void clear() {
    _exceededFrames.clear();
    _pause();
  }
}

/// Frame timing that represents an approximation of the frame's build duration.
@internal
class SentryFrameTiming {
  final DateTime startTimestamp;
  final DateTime endTimestamp;

  late final duration = endTimestamp.difference(startTimestamp);

  SentryFrameTiming(
    this.startTimestamp,
    this.endTimestamp,
  );
}
