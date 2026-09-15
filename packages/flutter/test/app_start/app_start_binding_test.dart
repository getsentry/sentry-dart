// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/app_start/app_start_frame_recorder.dart';
import 'package:sentry_flutter/src/app_start/app_start_frame_phases.dart';
import 'package:sentry_flutter/src/app_start/app_start_span_kind.dart';
import '../binding.dart';
import 'first_frame_timing.dart';

void main() {
  final binding = SentryAutomatedTestWidgetsFlutterBinding.ensureInitialized();
  group('Startup binding observations', () {
    late Fixture fixture;
    setUp(() {
      fixture = Fixture();
      // Install before the test binding attaches its initial root.
      binding.startAppStartRecording(fixture.getSut());
    });
    tearDown(() {
      binding.stopAppStartRecording(fixture.getSut());
      fixture.getSut().cancel();
    });
    testWidgets('record initial attachment and builds across nested deferral', (
      tester,
    ) async {
      binding.deferFirstFrame();
      binding.deferFirstFrame();
      try {
        await tester.pumpWidget(const SizedBox());
        binding.allowFirstFrame();
        binding.scheduleFrame();
        await tester.pump(const Duration(milliseconds: 16));
        expect(binding.sendFramesToEngine, isFalse);
      } finally {
        binding.allowFirstFrame();
      }
      binding.scheduleFrame();
      await tester.pump();
      final result = fixture.getSut().resolve(fixture.start, fixture.raster);
      expect(
        result.frameSpans.where(
          (span) => span.kind == AppStartSpanKind.rootWidgetAttachment,
        ),
        hasLength(1),
      );
      final builds = result.frameSpans.where(
        (span) => span.kind == AppStartSpanKind.frameBuild,
      );
      expect(
        builds.where((span) => span.data['app.start.frame.deferred'] == true),
        hasLength(2),
      );
      expect(builds.last.data['app.start.frame.deferred'], isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}

class Fixture {
  final start = DateTime.utc(2026);
  late DateTime now = start;
  late final recorder = AppStartFrameRecorder(
    clock: () {
      now = now.add(const Duration(milliseconds: 1));
      return now;
    },
  );
  AppStartFrameRecorder getSut() => recorder;
  late final raster = AppStartFramePhases.tryResolve(
    fakeFirstFrameTiming(
      vsyncStart: start.add(const Duration(milliseconds: 90)),
      buildStart: start.add(const Duration(milliseconds: 90)),
      buildFinish: start.add(const Duration(milliseconds: 91)),
      rasterStart: start.add(const Duration(milliseconds: 95)),
      rasterFinish: start.add(const Duration(milliseconds: 100)),
    ),
  )!;
}
