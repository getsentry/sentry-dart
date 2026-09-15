// ignore_for_file: invalid_use_of_internal_member
import 'package:sentry/sentry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/app_start/app_start_result.dart';
import 'package:sentry_flutter/src/app_start/app_start_recorder.dart';
import 'first_frame_timing.dart';

void main() {
  group('$AppStartRecorder', () {
    late Fixture fixture;
    setUp(() {
      fixture = Fixture();
    });
    test('records attachment and a deferred build before rasterization', () {
      final sut = fixture.getSut();
      sut.beginAttachment(hasRoot: false);
      fixture.advance(10);
      sut.endAttachment();
      sut.beginFrame(warmUp: true);
      fixture.advance(20);
      sut.endFrame(deferred: true);
      final result = sut.resolve(fixture.start, fixture.raster);
      expect(result.intervals.map((span) => span.operation), [
        SentrySpanOperations.appStartRootWidgetAttachment,
        SentrySpanOperations.appStartFrameBuild,
        SentrySpanOperations.appStartFrameRaster,
      ]);
      expect(result.intervals.map((span) => span.description), [
        'Root Widget Attachment',
        'Frame Build',
        'Frame Rasterization',
      ]);
      expect(result.intervals.map((span) => span.threadName), [
        'ui',
        'ui',
        'raster',
      ]);
      final build = result.intervals[1];
      expect(
        build.endTimestamp.difference(build.startTimestamp),
        const Duration(milliseconds: 20),
      );
      expect(build.data, {
        'flutter.frame.warm_up': true,
        'flutter.frame.deferred': true,
      });
    });

    test('retains at most ten complete builds and counts omitted detail', () {
      final sut = fixture.getSut();
      sut.beginAttachment(hasRoot: false);
      sut.endAttachment();
      for (var i = 0; i < 12; i++) {
        sut.beginFrame(warmUp: false);
        fixture.advance(1);
        sut.endFrame(deferred: true);
      }
      final result = sut.resolve(fixture.start, fixture.raster);
      expect(
        result.intervals.where(
          (span) => span.operation == SentrySpanOperations.appStartFrameBuild,
        ),
        hasLength(10),
      );
      expect(result.omittedBuilds, 2);
    });
    test(
      'omits later and crossing builds without changing raster completion',
      () {
        final sut = fixture.getSut();
        sut.beginAttachment(hasRoot: false);
        sut.endAttachment();
        fixture.advance(90);
        sut.beginFrame(warmUp: false);
        fixture.advance(20);
        sut.endFrame(deferred: false);
        sut.beginFrame(warmUp: false);
        fixture.advance(5);
        sut.endFrame(deferred: false);
        final result = sut.resolve(fixture.start, fixture.raster);
        expect(result.intervals.map((span) => span.operation), [
          SentrySpanOperations.appStartRootWidgetAttachment,
          SentrySpanOperations.appStartFrameRaster,
        ]);
        expect(
          result.rasterFinish,
          fixture.start.add(const Duration(milliseconds: 100)),
        );
      },
    );
    test('ignores work after cancellation and discards pending intervals', () {
      final sut = fixture.getSut();
      sut.beginAttachment(hasRoot: false);
      sut.endAttachment();
      sut.beginFrame(warmUp: true);
      sut.cancel();
      fixture.advance(5);
      sut.endFrame(deferred: false);
      sut.cancel();
      expect(
        sut
            .resolve(fixture.start, fixture.raster)
            .intervals
            .map((span) => span.operation),
        [SentrySpanOperations.appStartFrameRaster],
      );
    });
    test('freezes observations while native timing is pending', () {
      final sut = fixture.getSut();
      sut.beginAttachment(hasRoot: false);
      sut.endAttachment();
      sut.freeze();
      sut.beginFrame(warmUp: false);
      fixture.advance(1);
      sut.endFrame(deferred: false);
      expect(
        sut
            .resolve(fixture.start, fixture.raster)
            .intervals
            .map((span) => span.operation),
        [
          SentrySpanOperations.appStartRootWidgetAttachment,
          SentrySpanOperations.appStartFrameRaster,
        ],
      );
    });
    test('does not claim initial attachment for an existing root', () {
      final sut = fixture.getSut();
      sut.beginAttachment(hasRoot: true);
      sut.endAttachment();
      sut.beginFrame(warmUp: false);
      sut.endFrame(deferred: false);
      expect(
        sut
            .resolve(fixture.start, fixture.raster)
            .intervals
            .map((span) => span.operation),
        [SentrySpanOperations.appStartFrameRaster],
      );
    });
    test('does not record a failed build or unmatched completion', () {
      final sut = fixture.getSut();
      sut.beginAttachment(hasRoot: false);
      sut.endAttachment();
      sut.beginFrame(warmUp: true);
      fixture.advance(1);
      sut.endFrame(deferred: false, succeeded: false);
      sut.endFrame(deferred: false);
      expect(
        sut
            .resolve(fixture.start, fixture.raster)
            .intervals
            .map((span) => span.operation),
        [
          SentrySpanOperations.appStartRootWidgetAttachment,
          SentrySpanOperations.appStartFrameRaster,
        ],
      );
    });
    test('does not let clock failures escape into framework execution', () {
      final sut = AppStartRecorder(clock: () => throw StateError('clock'));
      expect(() {
        sut.beginAttachment(hasRoot: false);
        sut.endAttachment();
        sut.beginFrame(warmUp: true);
        sut.endFrame(deferred: false);
      }, returnsNormally);
      expect(
        sut
            .resolve(fixture.start, fixture.raster)
            .intervals
            .map((span) => span.operation),
        [SentrySpanOperations.appStartFrameRaster],
      );
    });
  });
}

class Fixture {
  final start = DateTime.utc(2026);
  late DateTime now = start;
  void advance(int milliseconds) =>
      now = now.add(Duration(milliseconds: milliseconds));
  late final raster = AppStartResult.tryResolve(
    fakeFirstFrameTiming(
      vsyncStart: start.add(const Duration(milliseconds: 90)),
      buildStart: start.add(const Duration(milliseconds: 90)),
      buildFinish: start.add(const Duration(milliseconds: 91)),
      rasterStart: start.add(const Duration(milliseconds: 95)),
      rasterFinish: start.add(const Duration(milliseconds: 100)),
    ),
  )!;
  AppStartRecorder getSut() => AppStartRecorder(clock: () => now);
}
