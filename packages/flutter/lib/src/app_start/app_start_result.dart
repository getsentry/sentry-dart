// ignore_for_file: invalid_use_of_internal_member
import 'dart:ui';

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

/// A measured startup interval, ready for either span protocol.
@internal
final class AppStartRecordedInterval {
  AppStartRecordedInterval({
    required this.description,
    required this.operation,
    this.threadName,
    required this.startTimestamp,
    required this.endTimestamp,
    Map<String, bool> data = const {},
  }) : data = Map.unmodifiable(data);

  final String description;
  final String operation;
  final String? threadName;
  final DateTime startTimestamp;
  final DateTime endTimestamp;
  final Map<String, bool> data;
}

/// Raster timing and optional directly observed framework intervals.
///
/// Engine build/vsync timestamps can be placeholders for warm-up frames.
/// Only raster timing is derived from [FrameTiming]; framework work must be
/// observed at the binding instead.
@internal
final class AppStartResult {
  AppStartResult._({
    required this.rasterFinish,
    required List<AppStartRecordedInterval> intervals,
  }) : intervals = List.unmodifiable(intervals);

  final DateTime rasterFinish;
  final List<AppStartRecordedInterval> intervals;

  AppStartResult withFrameworkIntervals(
    Iterable<AppStartRecordedInterval> frameworkIntervals,
  ) => AppStartResult._(
    rasterFinish: rasterFinish,
    intervals: [...frameworkIntervals, ...intervals],
  );

  static AppStartResult? tryResolve(FrameTiming timing) {
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
    if (rasterFinishWallMicros <= 0 ||
        rasterStartMicros < 0 ||
        rasterDurationMicros < 0 ||
        rasterDurationMicros > rasterFinishWallMicros) {
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
    return AppStartResult._(
      rasterFinish: rasterFinish,
      intervals: [
        AppStartRecordedInterval(
          description: 'Frame Rasterization',
          operation: SentrySpanOperations.appStartFrameRaster,
          threadName: 'raster',
          startTimestamp: rasterStart,
          endTimestamp: rasterFinish,
        ),
      ],
    );
  }
}
