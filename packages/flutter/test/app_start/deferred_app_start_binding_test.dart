// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/app_start/app_start_recorder.dart';
import '../binding.dart';

void main() {
  final binding = SentryAutomatedTestWidgetsFlutterBinding.ensureInitialized();
  group('Startup observation after deferred attachment', () {
    testWidgets('records only subsequent complete builds', (tester) async {
      final start = DateTime.utc(2026);
      var now = start;
      final recorder = AppStartRecorder(
        clock: () {
          now = now.add(const Duration(milliseconds: 1));
          return now;
        },
      );
      addTearDown(() {
        binding.stopAppStartRecording(recorder);
        recorder.cancel();
      });
      binding.deferFirstFrame();
      try {
        await tester.pumpWidget(const SizedBox());
        expect(binding.rootElement, isNotNull);
        expect(binding.sendFramesToEngine, isFalse);
        binding.startAppStartRecording(recorder);
        binding.scheduleFrame();
        await tester.pump();
      } finally {
        binding.allowFirstFrame();
      }
      binding.scheduleFrame();
      await tester.pump();
      final intervals = recorder.takeIntervals(
        processStart: start,
        rasterFinish: start.add(const Duration(seconds: 1)),
      );
      expect(intervals.map((interval) => interval.description), [
        'Frame Build',
        'Frame Build',
      ]);
      expect(
        intervals.map((interval) => interval.data['flutter.frame.deferred']),
        [true, false],
      );
      expect(tester.takeException(), isNull);
    });
  });
}
