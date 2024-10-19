// ignore_for_file: invalid_use_of_internal_member

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../sentry_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'native/sentry_native_binding.dart';

/// The methods and properties are modelled after the the real binding class.
@experimental
class BindingWrapper {
  final Hub _hub;

  BindingWrapper({Hub? hub}) : _hub = hub ?? HubAdapter();

  /// The current [WidgetsBinding], if one has been created.
  /// Provides access to the features exposed by this mixin.
  /// The binding must be initialized before using this getter;
  /// this is typically done by calling [runApp] or [WidgetsFlutterBinding.ensureInitialized].
  WidgetsBinding? get instance {
    try {
      return _ambiguate(WidgetsBinding.instance);
    } catch (e, s) {
      _hub.options.logger(
        SentryLevel.error,
        'WidgetsBinding.instance was not yet initialized',
        exception: e,
        stackTrace: s,
        logger: 'BindingWrapper',
      );
      if (_hub.options.automatedTestMode) {
        rethrow;
      }
      return null;
    }
  }

  /// Returns an instance of the binding that implements [WidgetsBinding].
  /// If no binding has yet been initialized, the [WidgetsFlutterBinding] class
  /// is used to create and initialize one.
  /// You only need to call this method if you need the binding to be
  /// initialized before calling [runApp].
  WidgetsBinding ensureInitialized() =>
      SentryWidgetsFlutterBinding.ensureInitialized();
}

WidgetsBinding? _ambiguate(WidgetsBinding? binding) => binding;

mixin FrameTrackingBindingMixin on WidgetsBinding {
  final stopwatch = Stopwatch();

  final tracker = FrameTracker(Sentry.currentHub.options);

  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    tracker.startFrame();

    super.handleBeginFrame(rawTimeStamp);
  }

  @override
  void handleDrawFrame() {
    super.handleDrawFrame();

    tracker.endFrame();
  }
}

class SentryWidgetsFlutterBinding extends WidgetsFlutterBinding
    with FrameTrackingBindingMixin {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
  }

  static SentryWidgetsFlutterBinding get instance =>
      BindingBase.checkInstance(_instance);
  static SentryWidgetsFlutterBinding? _instance;

  // ignore: prefer_constructors_over_static_methods
  static WidgetsBinding ensureInitialized() {
    try {
      if (SentryWidgetsFlutterBinding._instance == null) {
        SentryWidgetsFlutterBinding();
      }
      return SentryWidgetsFlutterBinding.instance;
    } catch (e) {
      HubAdapter().options.logger(
          SentryLevel.info,
          'WidgetsFlutterBinding already initialized. '
          'Falling back to default WidgetsBinding instance.');
      return WidgetsBinding.instance;
    }
  }
}

class FrameTracker {
  FrameTracker(this._options);

  final SentryOptions _options;

  List<FrameTiming> get exceededFrames => _exceededFrames;
  final List<FrameTiming> _exceededFrames = [];

  /// Stores the start time of the current frame.
  DateTime? _currentFrameStartTimestamp;

  void startFrame() {
    _currentFrameStartTimestamp = _options.clock();
  }

  void endFrame() {
    final startTime = _currentFrameStartTimestamp;
    if (startTime != null) {
      final endTimestamp = _options.clock();
      final frameTiming = FrameTiming(startTime, endTimestamp);
      _exceededFrames.add(frameTiming);
      _currentFrameStartTimestamp = null;
    }
  }

  /// Removes frames whose endTime is before [time].
  void removeFramesBefore(DateTime time) {
    _exceededFrames.removeWhere((frame) => frame.endTimestamp.isBefore(time));
  }
}

/// Frame timing that represents an approximation of the frame's build duration.
class FrameTiming {
  final DateTime startTimestamp;
  final DateTime endTimestamp;

  Duration get duration {
    return endTimestamp.difference(startTimestamp);
  }

  FrameTiming(
    this.startTimestamp,
    this.endTimestamp,
  );
}

// TODO: maybe could be an extension
class SpanFrameMetricsCalculator {
  SpanFrameMetricsCalculator(this._expectedFrameDuration,
      {SentryOptions? options})
      : _options = options ?? Sentry.currentHub.options;

  final _frozenFrameThreshold = Duration(milliseconds: 700);
  final Duration _expectedFrameDuration;
  final SentryOptions _options;

  SpanFrameMetrics? calculateFor(
      ISentrySpan span, List<FrameTiming> frameTimings) {
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

    final spanDuration =
        spanEndTimestamp.difference(span.startTimestamp).inMilliseconds;
    final normalFramesCount =
        (spanDuration - (slowFramesDuration + frozenFramesDuration)) /
            _expectedFrameDuration.inMilliseconds;
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
}
