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
    this.omittedBuilds = 0,
  }) : intervals = List.unmodifiable(intervals);

  final DateTime rasterFinish;
  final List<AppStartRecordedInterval> intervals;
  final int omittedBuilds;

  AppStartResult withFrameworkIntervals(
    Iterable<AppStartRecordedInterval> frameworkIntervals, {
    required int omittedBuilds,
  }) => AppStartResult._(
    rasterFinish: rasterFinish,
    intervals: [...frameworkIntervals, ...intervals],
    omittedBuilds: omittedBuilds,
  );

  static AppStartResult? tryResolve(FrameTiming timing) {
    final anchor = timing.timestampInMicroseconds(
      FramePhase.rasterFinishWallTime,
    );
    final start = timing.timestampInMicroseconds(FramePhase.rasterStart);
    final finish = timing.timestampInMicroseconds(FramePhase.rasterFinish);
    final duration = finish - start;
    if (anchor <= 0 || start < 0 || duration < 0 || duration > anchor) {
      return null;
    }

    // The engine timestamps use a different epoch. Project the duration back
    // from its wall-clock endpoint rather than interpreting them as dates.
    final rasterFinish = DateTime.fromMicrosecondsSinceEpoch(
      anchor,
      isUtc: true,
    );
    final rasterStart = rasterFinish.subtract(Duration(microseconds: duration));
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
