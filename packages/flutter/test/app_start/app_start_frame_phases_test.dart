import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/app_start/app_start_frame_phases.dart';
import 'package:sentry_flutter/src/app_start/app_start_span_kind.dart';

void main() {
  group('$AppStartFramePhases', () {
    late Fixture fixture;
    setUp(() {
      fixture = Fixture();
    });
    test('does not infer framework work from engine build timestamps', () {
      final phases = AppStartFramePhases.tryResolve(fixture.timing())!;
      expect(phases.frameSpans.map((span) => span.kind), [
        AppStartSpanKind.frameRaster,
      ]);
    });
    test('anchors raster duration on the wall clock endpoint', () {
      final phases = AppStartFramePhases.tryResolve(fixture.timing())!;
      expect(phases.rasterStart, DateTime.utc(2024, 1, 1, 12, 0, 0, 812));
      expect(phases.rasterFinish, fixture.rasterFinishWall);
    });
    test(
      'retains raster timing when engine build timestamps are inconsistent',
      () {
        final phases = AppStartFramePhases.tryResolve(
          fixture.timing(buildStart: 0, buildFinish: 999999),
        )!;
        expect(phases.frameSpans.single.endTimestamp, fixture.rasterFinishWall);
      },
    );
    test('rejects reversed raster timing', () {
      expect(
        AppStartFramePhases.tryResolve(fixture.timing(rasterStart: 900000)),
        isNull,
      );
    });
    test('rejects missing wall clock timing', () {
      expect(
        AppStartFramePhases.tryResolve(
          fixture.timing(rasterFinishWallTime: DateTime.utc(1970)),
        ),
        isNull,
      );
    });
  });
}

class Fixture {
  /// Arbitrary offset standing in for the engine's monotonic epoch, which does
  /// not match `DateTime`'s. Every phase below is derived relative to it, so a
  /// resolver that reads the phases as epoch microseconds lands in 1970.
  static const _monotonicEpochOffset = 5000000;

  final rasterFinishWall = DateTime.utc(2024, 1, 1, 12, 0, 0, 869);

  FrameTiming timing({
    int vsyncStart = 745000,
    int buildStart = 752000,
    int buildFinish = 803000,
    int rasterStart = 812000,
    int rasterFinish = 869000,
    DateTime? rasterFinishWallTime,
  }) => FrameTiming(
    vsyncStart: _monotonicEpochOffset + vsyncStart,
    buildStart: _monotonicEpochOffset + buildStart,
    buildFinish: _monotonicEpochOffset + buildFinish,
    rasterStart: _monotonicEpochOffset + rasterStart,
    rasterFinish: _monotonicEpochOffset + rasterFinish,
    rasterFinishWallTime:
        (rasterFinishWallTime ?? rasterFinishWall).microsecondsSinceEpoch,
  );
}
