import 'package:sentry/sentry.dart';
// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/app_start/app_start_recorder.dart';
import 'package:sentry_flutter/src/app_start/app_start_timing.dart';
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
      final intervals = fixture.getSut().resolve(
        processStart: fixture.start,
        rasterFinish: fixture.rasterInterval.endTimestamp,
      );
      expect(
        intervals.where(
          (interval) =>
              interval.operation ==
              SentrySpanOperations.appStartRootWidgetAttachment,
        ),
        hasLength(1),
      );
      final builds = intervals.where(
        (interval) =>
            interval.operation == SentrySpanOperations.appStartFrameBuild,
      );
      expect(
        builds.where(
          (interval) => interval.data['flutter.frame.deferred'] == true,
        ),
        hasLength(2),
      );
      expect(builds.last.data['flutter.frame.deferred'], isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}

class Fixture {
  final start = DateTime.utc(2026);
  late DateTime now = start;
  late final recorder = AppStartRecorder(
    clock: () {
      now = now.add(const Duration(milliseconds: 1));
      return now;
    },
  );
  AppStartRecorder getSut() => recorder;
  late final rasterInterval = tryResolveAppStartRasterInterval(
    fakeFirstFrameTiming(
      vsyncStart: start.add(const Duration(milliseconds: 90)),
      buildStart: start.add(const Duration(milliseconds: 90)),
      buildFinish: start.add(const Duration(milliseconds: 91)),
      rasterStart: start.add(const Duration(milliseconds: 95)),
      rasterFinish: start.add(const Duration(milliseconds: 100)),
    ),
  )!;
}
