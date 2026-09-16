// ignore_for_file: invalid_use_of_internal_member
import 'package:sentry/sentry.dart';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/app_start/app_start_result.dart';

void main() {
  group('$AppStartResult', () {
    late Fixture fixture;
    setUp(() {
      fixture = Fixture();
    });
    test('anchors raster duration on the wall clock endpoint', () {
      final timings = AppStartResult.tryResolve(fixture.timing())!;
      expect(
        timings.intervals.single.startTimestamp,
        DateTime.utc(2024, 1, 1, 12, 0, 0, 812),
      );
      expect(timings.rasterFinish, fixture.rasterFinishWall);
    });
    test(
      'emits only raster timing when engine build timestamps are inconsistent',
      () {
        final timings = AppStartResult.tryResolve(
          fixture.timing(buildStart: 0, buildFinish: 999999),
        )!;
        expect(timings.intervals.map((interval) => interval.operation), [
          SentrySpanOperations.appStartFrameRaster,
        ]);
        expect(timings.intervals.single.endTimestamp, fixture.rasterFinishWall);
      },
    );
    test('rejects reversed raster timing', () {
      expect(
        AppStartResult.tryResolve(fixture.timing(rasterStart: 900000)),
        isNull,
      );
    });
    test('rejects missing wall clock timing', () {
      expect(
        AppStartResult.tryResolve(
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
  /// resolver that reads the timings as epoch microseconds lands in 1970.
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
