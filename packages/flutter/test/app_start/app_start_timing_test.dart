// ignore_for_file: invalid_use_of_internal_member
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/app_start/app_start_timing.dart';
import 'package:sentry_flutter/src/native/native_app_start.dart';

void main() {
  group('$AppStartTiming parsing', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('parses intrinsic timing and sorts valid native intervals', () {
      final data = fixture.parse();

      expect(data, isNotNull);
      expect(data!.type, AppStartType.cold);
      expect(data.intervals.map((interval) => interval.description), [
        'early',
        'late',
      ]);
    });

    test('returns null when plugin registration precedes process start', () {
      final data = fixture.parse(
        pluginRegistration: fixture.processStart.subtract(
          Duration(milliseconds: 1),
        ),
      );

      expect(data, isNull);
    });

    test('returns null when setup precedes plugin registration', () {
      final data = fixture.parse(
        sentrySetup: fixture.pluginRegistration.subtract(
          Duration(milliseconds: 1),
        ),
      );

      expect(data, isNull);
    });

    test('discards one malformed optional interval', () {
      fixture.nativeSpanTimes['invalid'] = {
        'startTimestampMsSinceEpoch': fixture.firstFrame.millisecondsSinceEpoch,
        'stopTimestampMsSinceEpoch':
            fixture.processStart.millisecondsSinceEpoch,
      };

      final data = fixture.parse();

      expect(data!.intervals.map((interval) => interval.description), [
        'early',
        'late',
      ]);
    });

    test('discards optional intervals starting before process start', () {
      fixture.nativeSpanTimes['before-process-start'] = {
        'startTimestampMsSinceEpoch': fixture.processStart
            .subtract(Duration(milliseconds: 2))
            .millisecondsSinceEpoch,
        'stopTimestampMsSinceEpoch': fixture.processStart
            .subtract(Duration(milliseconds: 1))
            .millisecondsSinceEpoch,
      };

      final data = fixture.parse();

      expect(data!.intervals.map((interval) => interval.description), [
        'early',
        'late',
      ]);
    });
  });

  group('$AppStartTiming reportable duration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('returns the duration up to the given end', () {
      final timing = fixture.parse()!;

      expect(
        timing.reportableDurationUntil(fixture.firstFrame),
        Duration(milliseconds: 300),
      );
    });

    test('returns null when longer than sixty seconds', () {
      final timing = fixture.parse()!;

      final duration = timing.reportableDurationUntil(
        fixture.processStart.add(Duration(seconds: 61)),
      );

      expect(duration, isNull);
    });

    test('returns null when the end precedes process start', () {
      final timing = fixture.parse()!;

      final duration = timing.reportableDurationUntil(
        fixture.processStart.subtract(Duration(milliseconds: 1)),
      );

      expect(duration, isNull);
    });
  });
  group('tryResolveAppStartRasterInterval', () {
    late RasterFixture fixture;
    setUp(() {
      fixture = RasterFixture();
    });
    test('anchors raster duration on the wall clock endpoint', () {
      final result = tryResolveAppStartRasterInterval(fixture.frameTiming())!;
      expect(result.startTimestamp, DateTime.utc(2024, 1, 1, 12, 0, 0, 812));
      expect(result.endTimestamp, fixture.rasterFinishWall);
    });
    test(
      'emits only raster timing when engine build timestamps are inconsistent',
      () {
        final result = tryResolveAppStartRasterInterval(
          fixture.frameTiming(buildStart: 0, buildFinish: 999999),
        )!;
        expect(result.operation, SentrySpanOperations.appStartFrameRaster);
        expect(result.endTimestamp, fixture.rasterFinishWall);
      },
    );
    test('rejects reversed raster timing', () {
      expect(
        tryResolveAppStartRasterInterval(
          fixture.frameTiming(rasterStart: 900000),
        ),
        isNull,
      );
    });
    test('rejects missing wall clock timing', () {
      expect(
        tryResolveAppStartRasterInterval(
          fixture.frameTiming(rasterFinishWallTime: DateTime.utc(1970)),
        ),
        isNull,
      );
    });
  });
}

class Fixture {
  final processStart = DateTime.utc(2024, 1, 1, 12);
  late final pluginRegistration = processStart.add(Duration(milliseconds: 100));
  late final sentrySetup = processStart.add(Duration(milliseconds: 200));
  late final firstFrame = processStart.add(Duration(milliseconds: 300));

  /// Keyed newest-first, so a correct parse has to sort rather than lean on
  /// insertion order.
  late Map<dynamic, dynamic> nativeSpanTimes = <dynamic, dynamic>{
    'late': {
      'startTimestampMsSinceEpoch': processStart
          .add(Duration(milliseconds: 50))
          .millisecondsSinceEpoch,
      'stopTimestampMsSinceEpoch': processStart
          .add(Duration(milliseconds: 60))
          .millisecondsSinceEpoch,
    },
    'early': {
      'startTimestampMsSinceEpoch': processStart
          .add(Duration(milliseconds: 10))
          .millisecondsSinceEpoch,
      'stopTimestampMsSinceEpoch': processStart
          .add(Duration(milliseconds: 20))
          .millisecondsSinceEpoch,
    },
  };

  AppStartTiming? parse({
    DateTime? appStartTime,
    DateTime? pluginRegistration,
    DateTime? sentrySetup,
  }) => AppStartTiming.tryParse(
    NativeAppStart(
      appStartTime: (appStartTime ?? processStart).millisecondsSinceEpoch,
      pluginRegistrationTime: (pluginRegistration ?? this.pluginRegistration)
          .millisecondsSinceEpoch,
      isColdStart: true,
      nativeSpanTimes: nativeSpanTimes,
    ),
    sentrySetupTimestamp: sentrySetup ?? this.sentrySetup,
  );
}

class RasterFixture {
  /// Arbitrary offset standing in for the engine's monotonic epoch, which does
  /// not match `DateTime`'s. Every phase below is derived relative to it, so a
  /// resolver that reads the timings as epoch microseconds lands in 1970.
  static const _monotonicEpochOffset = 5000000;

  final rasterFinishWall = DateTime.utc(2024, 1, 1, 12, 0, 0, 869);

  FrameTiming frameTiming({
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
