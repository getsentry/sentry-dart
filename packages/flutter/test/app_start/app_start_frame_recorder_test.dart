// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/app_start/app_start_frame_phases.dart';
import 'package:sentry_flutter/src/app_start/app_start_frame_recorder.dart';
import 'package:sentry_flutter/src/app_start/app_start_span_kind.dart';
import 'first_frame_timing.dart';

void main() {
  group('$AppStartFrameRecorder', () {
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
      expect(result.frameSpans.map((span) => span.kind), [
        AppStartSpanKind.rootWidgetAttachment,
        AppStartSpanKind.frameBuild,
        AppStartSpanKind.frameRaster,
      ]);
      final build = result.frameSpans[1];
      expect(
        build.endTimestamp.difference(build.startTimestamp),
        const Duration(milliseconds: 20),
      );
      expect(build.data, {
        'app.start.frame.warm_up': true,
        'app.start.frame.deferred': true,
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
        result.frameSpans.where(
          (span) => span.kind == AppStartSpanKind.frameBuild,
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
        expect(result.frameSpans.map((span) => span.kind), [
          AppStartSpanKind.rootWidgetAttachment,
          AppStartSpanKind.frameRaster,
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
            .frameSpans
            .map((span) => span.kind),
        [AppStartSpanKind.frameRaster],
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
            .frameSpans
            .map((span) => span.kind),
        [AppStartSpanKind.rootWidgetAttachment, AppStartSpanKind.frameRaster],
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
            .frameSpans
            .map((span) => span.kind),
        [AppStartSpanKind.frameRaster],
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
            .frameSpans
            .map((span) => span.kind),
        [AppStartSpanKind.rootWidgetAttachment, AppStartSpanKind.frameRaster],
      );
    });
    test('does not let clock failures escape into framework execution', () {
      final sut = AppStartFrameRecorder(clock: () => throw StateError('clock'));
      expect(() {
        sut.beginAttachment(hasRoot: false);
        sut.endAttachment();
        sut.beginFrame(warmUp: true);
        sut.endFrame(deferred: false);
      }, returnsNormally);
      expect(
        sut
            .resolve(fixture.start, fixture.raster)
            .frameSpans
            .map((span) => span.kind),
        [AppStartSpanKind.frameRaster],
      );
    });
  });
}

class Fixture {
  final start = DateTime.utc(2026);
  late DateTime now = start;
  void advance(int milliseconds) =>
      now = now.add(Duration(milliseconds: milliseconds));
  late final raster = AppStartFramePhases.tryResolve(
    fakeFirstFrameTiming(
      vsyncStart: start.add(const Duration(milliseconds: 90)),
      buildStart: start.add(const Duration(milliseconds: 90)),
      buildFinish: start.add(const Duration(milliseconds: 91)),
      rasterStart: start.add(const Duration(milliseconds: 95)),
      rasterFinish: start.add(const Duration(milliseconds: 100)),
    ),
  )!;
  AppStartFrameRecorder getSut() => AppStartFrameRecorder(clock: () => now);
}
