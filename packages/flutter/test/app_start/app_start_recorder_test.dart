// ignore_for_file: invalid_use_of_internal_member
import 'package:sentry/sentry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/app_start/app_start_timing.dart';
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
      sut.beginRootAttachment(hasRoot: false);
      fixture.advance(10);
      sut.endRootAttachment();
      sut.beginFrameBuild(warmUp: true);
      fixture.advance(20);
      sut.endFrameBuild(deferred: true);
      final intervals = sut.takeIntervals(
        processStart: fixture.start,
        rasterFinish: fixture.rasterInterval.endTimestamp,
      );
      expect(intervals.map((interval) => interval.operation), [
        SentrySpanOperations.appStartRootWidgetAttachment,
        SentrySpanOperations.appStartFrameBuild,
      ]);
      expect(intervals.map((interval) => interval.description), [
        'Root Widget Attachment',
        'Frame Build',
      ]);
      final build = intervals[1];
      expect(
        build.endTimestamp.difference(build.startTimestamp),
        const Duration(milliseconds: 20),
      );
      expect(build.data, {
        'flutter.frame.warm_up': true,
        'flutter.frame.deferred': true,
      });
    });

    test('retains at most ten complete builds', () {
      final sut = fixture.getSut();
      sut.beginRootAttachment(hasRoot: false);
      sut.endRootAttachment();
      for (var i = 0; i < 12; i++) {
        sut.beginFrameBuild(warmUp: false);
        fixture.advance(1);
        sut.endFrameBuild(deferred: true);
      }
      final intervals = sut.takeIntervals(
        processStart: fixture.start,
        rasterFinish: fixture.rasterInterval.endTimestamp,
      );
      expect(
        intervals.where(
          (interval) =>
              interval.operation == SentrySpanOperations.appStartFrameBuild,
        ),
        hasLength(10),
      );
    });
    test('omits builds crossing or following raster completion', () {
      final sut = fixture.getSut();
      sut.beginRootAttachment(hasRoot: false);
      sut.endRootAttachment();
      fixture.advance(90);
      sut.beginFrameBuild(warmUp: false);
      fixture.advance(20);
      sut.endFrameBuild(deferred: false);
      sut.beginFrameBuild(warmUp: false);
      fixture.advance(5);
      sut.endFrameBuild(deferred: false);
      final intervals = sut.takeIntervals(
        processStart: fixture.start,
        rasterFinish: fixture.rasterInterval.endTimestamp,
      );
      expect(intervals.map((interval) => interval.operation), [
        SentrySpanOperations.appStartRootWidgetAttachment,
      ]);
    });
    test('ignores work after cancellation and discards pending intervals', () {
      final sut = fixture.getSut();
      sut.beginRootAttachment(hasRoot: false);
      sut.endRootAttachment();
      sut.beginFrameBuild(warmUp: true);
      sut.cancel();
      fixture.advance(5);
      sut.endFrameBuild(deferred: false);
      sut.cancel();
      expect(
        sut
            .takeIntervals(
              processStart: fixture.start,
              rasterFinish: fixture.rasterInterval.endTimestamp,
            )
            .map((interval) => interval.operation),
        <String>[],
      );
    });
    test('freezes observations while native timing is pending', () {
      final sut = fixture.getSut();
      sut.beginRootAttachment(hasRoot: false);
      sut.endRootAttachment();
      sut.freeze();
      sut.beginFrameBuild(warmUp: false);
      fixture.advance(1);
      sut.endFrameBuild(deferred: false);
      expect(
        sut
            .takeIntervals(
              processStart: fixture.start,
              rasterFinish: fixture.rasterInterval.endTimestamp,
            )
            .map((interval) => interval.operation),
        [SentrySpanOperations.appStartRootWidgetAttachment],
      );
    });
    test('records complete builds without observing root attachment', () {
      final sut = fixture.getSut();
      // Completion of a build that began before observation must be ignored.
      sut.endFrameBuild(deferred: true);
      fixture.advance(5);
      sut.beginFrameBuild(warmUp: false);
      fixture.advance(10);
      sut.endFrameBuild(deferred: false);
      final intervals = sut.takeIntervals(
        processStart: fixture.start,
        rasterFinish: fixture.rasterInterval.endTimestamp,
      );
      expect(intervals, hasLength(1));
      expect(intervals.single.description, 'Frame Build');
      expect(
        intervals.single.startTimestamp,
        fixture.start.add(const Duration(milliseconds: 5)),
      );
      expect(
        intervals.single.endTimestamp,
        fixture.start.add(const Duration(milliseconds: 15)),
      );
    });

    test('does not claim initial attachment for an existing root', () {
      final sut = fixture.getSut();
      sut.beginRootAttachment(hasRoot: true);
      sut.endRootAttachment();
      expect(
        sut.takeIntervals(
          processStart: fixture.start,
          rasterFinish: fixture.rasterInterval.endTimestamp,
        ),
        isEmpty,
      );
    });
    test('does not record a failed build or unmatched completion', () {
      final sut = fixture.getSut();
      sut.beginRootAttachment(hasRoot: false);
      sut.endRootAttachment();
      sut.beginFrameBuild(warmUp: true);
      fixture.advance(1);
      sut.endFrameBuild(deferred: false, succeeded: false);
      sut.endFrameBuild(deferred: false);
      expect(
        sut
            .takeIntervals(
              processStart: fixture.start,
              rasterFinish: fixture.rasterInterval.endTimestamp,
            )
            .map((interval) => interval.operation),
        [SentrySpanOperations.appStartRootWidgetAttachment],
      );
    });
    test('does not let clock failures escape into framework execution', () {
      final sut = AppStartRecorder(clock: () => throw StateError('clock'));
      expect(() {
        sut.beginRootAttachment(hasRoot: false);
        sut.endRootAttachment();
        sut.beginFrameBuild(warmUp: true);
        sut.endFrameBuild(deferred: false);
      }, returnsNormally);
      expect(
        sut
            .takeIntervals(
              processStart: fixture.start,
              rasterFinish: fixture.rasterInterval.endTimestamp,
            )
            .map((interval) => interval.operation),
        <String>[],
      );
    });
  });
}

class Fixture {
  final start = DateTime.utc(2026);
  late DateTime now = start;
  void advance(int milliseconds) =>
      now = now.add(Duration(milliseconds: milliseconds));
  late final rasterInterval = tryResolveAppStartRasterInterval(
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
