// ignore_for_file: invalid_use_of_internal_member

import 'dart:ui';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../native/native_app_start.dart';
import '../utils/internal_logger.dart';

/// Rejects app starts older / longer than 60s (late init, backgrounded
/// process, OS forking, or unreproducible outliers).
const _maxAppStartAge = Duration(seconds: 60);

/// Startup work before `SentryFlutter.init` began.
/// Native plugin registration depends on plugin ordering, so it validates
/// timestamp ordering but does not define a separate span.
@internal
const appStartPreInitDescription = 'Pre-Init Startup';

@internal
enum AppStartType { cold, warm }

/// Validated native timing and startup intervals.
/// [reportableDurationUntil] checks launch duration once the endpoint is known.
@internal
final class AppStartTiming {
  AppStartTiming({
    required this.type,
    required this.processStartTimestamp,
    required this.sentrySetupTimestamp,
    required this.intervals,
  });

  final AppStartType type;
  final DateTime processStartTimestamp;
  final DateTime sentrySetupTimestamp;

  /// Native detail intervals plus the pre-init roll-up, ready to become spans.
  final List<AppStartRecordedInterval> intervals;

  /// Returns `null` for negative durations or launches longer than 60 seconds.
  /// Rejects rather than clamps outliers to avoid reporting misleading durations.
  Duration? reportableDurationUntil(DateTime endTimestamp) {
    final duration = endTimestamp.difference(processStartTimestamp);
    return duration.isNegative || duration > _maxAppStartAge ? null : duration;
  }

  SentryMeasurement measurementFor(Duration duration) =>
      type == AppStartType.cold
      ? SentryMeasurement.coldAppStart(duration)
      : SentryMeasurement.warmAppStart(duration);

  /// Parses native intervals, rejecting inconsistent startup timestamp ordering.
  /// [sentrySetupTimestamp] marks the start of `SentryFlutter.init` and ends
  /// pre-init. Duration validation is separate: see [reportableDurationUntil].
  static AppStartTiming? tryParse(
    NativeAppStart nativeAppStart, {
    required DateTime sentrySetupTimestamp,
  }) {
    final processStart = DateTime.fromMillisecondsSinceEpoch(
      nativeAppStart.appStartTime,
      isUtc: true,
    );
    final pluginRegistration = DateTime.fromMillisecondsSinceEpoch(
      nativeAppStart.pluginRegistrationTime,
      isUtc: true,
    );
    final setup = sentrySetupTimestamp.toUtc();

    if (pluginRegistration.isBefore(processStart) ||
        setup.isBefore(pluginRegistration)) {
      return null;
    }

    return AppStartTiming(
      type: nativeAppStart.isColdStart ? AppStartType.cold : AppStartType.warm,
      processStartTimestamp: processStart,
      sentrySetupTimestamp: setup,
      intervals: [
        ..._parseNativeIntervals(
          nativeAppStart,
          earliestTimestamp: processStart,
        ),
        AppStartRecordedInterval(
          operation: SentrySpanOperations.appStartPreInit,
          description: appStartPreInitDescription,
          startTimestamp: processStart,
          endTimestamp: setup,
        ),
      ],
    );
  }

  static List<AppStartRecordedInterval> _parseNativeIntervals(
    NativeAppStart nativeAppStart, {
    required DateTime earliestTimestamp,
  }) {
    final intervals = <AppStartRecordedInterval>[];
    for (final entry in nativeAppStart.nativeSpanTimes.entries) {
      try {
        final value = entry.value;
        final startMilliseconds = value['startTimestampMsSinceEpoch'] as int;
        final endMilliseconds = value['stopTimestampMsSinceEpoch'] as int;
        final start = DateTime.fromMillisecondsSinceEpoch(
          startMilliseconds,
          isUtc: true,
        );
        final end = DateTime.fromMillisecondsSinceEpoch(
          endMilliseconds,
          isUtc: true,
        );
        if (end.isBefore(start) || start.isBefore(earliestTimestamp)) {
          continue;
        }
        intervals.add(
          AppStartRecordedInterval(
            operation: SentrySpanOperations.appStartNative,
            description: entry.key as String,
            startTimestamp: start,
            endTimestamp: end,
          ),
        );
      } catch (error, stackTrace) {
        internalLogger.warning(
          'Failed to parse native app-start interval',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    intervals.sort((a, b) => a.startTimestamp.compareTo(b.startTimestamp));
    return intervals;
  }
}

/// A measured startup interval, ready for either span protocol.
@internal
final class AppStartRecordedInterval {
  AppStartRecordedInterval({
    required this.description,
    required this.operation,
    required this.startTimestamp,
    required this.endTimestamp,
    Map<String, bool> data = const {},
  }) : data = Map.unmodifiable(data);

  final String description;
  final String operation;
  final DateTime startTimestamp;
  final DateTime endTimestamp;
  final Map<String, bool> data;
}

/// Resolves the engine's raster timestamps to one wall-clock interval.
/// Build/vsync timestamps may be placeholders for warm-up frames, so they
/// cannot supply framework intervals here.
@internal
AppStartRecordedInterval? tryResolveAppStartRasterInterval(FrameTiming timing) {
  final rasterFinishWallMicros = timing.timestampInMicroseconds(
    FramePhase.rasterFinishWallTime,
  );
  final rasterStartMicros = timing.timestampInMicroseconds(
    FramePhase.rasterStart,
  );
  final rasterFinishMicros = timing.timestampInMicroseconds(
    FramePhase.rasterFinish,
  );
  final rasterDurationMicros = rasterFinishMicros - rasterStartMicros;
  if (rasterFinishWallMicros <= 0 || rasterDurationMicros < 0) {
    return null;
  }

  // The engine timestamps use a different epoch. Project the duration back
  // from its wall-clock endpoint rather than interpreting them as dates.
  final rasterFinish = DateTime.fromMicrosecondsSinceEpoch(
    rasterFinishWallMicros,
    isUtc: true,
  );
  final rasterStart = rasterFinish.subtract(
    Duration(microseconds: rasterDurationMicros),
  );
  return AppStartRecordedInterval(
    description: 'Frame Rasterization',
    operation: SentrySpanOperations.appStartFrameRaster,
    startTimestamp: rasterStart,
    endTimestamp: rasterFinish,
  );
}
