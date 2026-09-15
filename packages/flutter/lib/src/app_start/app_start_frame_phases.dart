import 'dart:ui';

import 'package:meta/meta.dart';

import 'app_start_span_kind.dart';

/// A measured startup interval, ready for either span protocol.
@internal
final class AppStartFrameSpan {
  AppStartFrameSpan({
    required this.kind,
    required this.startTimestamp,
    required this.endTimestamp,
    Map<String, bool> data = const {},
  }) : data = Map.unmodifiable(data);

  final AppStartSpanKind kind;
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
final class AppStartFramePhases {
  AppStartFramePhases._({
    required this.rasterStart,
    required this.rasterFinish,
    required List<AppStartFrameSpan> frameSpans,
    this.omittedBuilds = 0,
  }) : frameSpans = List.unmodifiable(frameSpans);

  final DateTime rasterStart;
  final DateTime rasterFinish;
  final List<AppStartFrameSpan> frameSpans;
  final int omittedBuilds;

  AppStartFramePhases withFrameworkSpans(
    List<AppStartFrameSpan> spans, {
    required int omittedBuilds,
  }) => AppStartFramePhases._(
    rasterStart: rasterStart,
    rasterFinish: rasterFinish,
    frameSpans: [...spans, ...frameSpans],
    omittedBuilds: omittedBuilds,
  );

  static AppStartFramePhases? tryResolve(FrameTiming timing) {
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
    return AppStartFramePhases._(
      rasterStart: rasterStart,
      rasterFinish: rasterFinish,
      frameSpans: [
        AppStartFrameSpan(
          kind: AppStartSpanKind.frameRaster,
          startTimestamp: rasterStart,
          endTimestamp: rasterFinish,
        ),
      ],
    );
  }
}
