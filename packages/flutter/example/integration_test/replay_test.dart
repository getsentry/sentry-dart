// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter_example/main.dart';
import 'package:sentry_flutter/src/native/java/sentry_native_java.dart';
import 'package:sentry_flutter/src/replay/replay_config.dart';
import 'package:sentry_flutter/src/replay/scheduled_recorder_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  IntegrationTestWidgetsFlutterBinding.instance.framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

  tearDown(() async {
    await Sentry.close();
  });

  Future<void> setupSentryAndApp(WidgetTester tester, {String? dsn}) async {
    await setupSentry(
      () async {
        await tester.pumpWidget(SentryScreenshotWidget(
            child: DefaultAssetBundle(
          bundle: SentryAssetBundle(enableStructuredDataTracing: true),
          child: const MyApp(),
        )));
      },
      dsn ?? fakeDsn,
      isIntegrationTest: true,
    );
  }

  group('Replay recording', () {
    testWidgets('native binding is initialized', (tester) async {
      await setupSentryAndApp(tester);
      expect(SentryFlutter.native, isNotNull);
    });

    testWidgets('supportsReplay matches platform', (tester) async {
      await setupSentryAndApp(tester);
      final supports = SentryFlutter.native?.supportsReplay ?? false;
      expect(supports, Platform.isAndroid || Platform.isIOS ? isTrue : isFalse);
    });

    testWidgets('captureReplay returns a SentryId', (tester) async {
      if (!(Platform.isAndroid || Platform.isIOS)) return;
      await setupSentryAndApp(tester);
      final id = await SentryFlutter.native?.captureReplay();
      expect(id, isA<SentryId>());
      if (Platform.isIOS) {
        final current = SentryFlutter.native?.replayId;
        expect(current?.toString(), equals(id?.toString()));
      }
    });

    testWidgets('captureReplay sets native replay ID', (tester) async {
      if (!(Platform.isAndroid || Platform.isIOS)) return;
      await setupSentryAndApp(tester);
      final id = await SentryFlutter.native?.captureReplay();
      expect(id, isA<SentryId>());
      expect(SentryFlutter.native?.replayId, isNotNull);
      expect(SentryFlutter.native?.replayId, isNot(const SentryId.empty()));
    });

    // We would like to add a test that ensures a native-initiated replay stop
    // clears the replay ID from the scope. Currently we can't add that test
    // because FFI/JNI cannot be mocked in this environment.
    testWidgets('sets replay ID after capturing exception', (tester) async {
      await setupSentryAndApp(tester);

      try {
        throw Exception('boom');
      } catch (e, st) {
        await Sentry.captureException(e, stackTrace: st);
      }

      // After capture, ReplayEventProcessor should set scope.replayId
      await Sentry.configureScope((scope) async {
        expect(
            scope.replayId == null || scope.replayId == const SentryId.empty(),
            isFalse);
      });

      final current = SentryFlutter.native?.replayId;
      await Sentry.configureScope((scope) async {
        expect(current?.toString(), equals(scope.replayId?.toString()));
      });
    });

    testWidgets(
        'replay recorder start emits frame and stop silences frames on Android',
        (tester) async {
      await setupSentryAndApp(tester);
      final native = SentryFlutter.native as SentryNativeJava?;
      expect(native, isNotNull);

      await Future.delayed(const Duration(seconds: 2));
      final recorder = native!.testRecorder!;

      var frameCount = 0;
      final firstFrame = Completer<void>();
      recorder.onScreenshotAddedForTest = () {
        frameCount++;
        if (!firstFrame.isCompleted) firstFrame.complete();
      };

      await recorder
          .onConfigurationChanged(const ScheduledScreenshotRecorderConfig(
        width: 800,
        height: 600,
        frameRate: 1,
      ));

      await tester.pump();
      await firstFrame.future.timeout(const Duration(seconds: 5));

      await recorder.stop();
      await tester.pump();
      final afterStopCount = frameCount;
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(frameCount, equals(afterStopCount));
    }, skip: !Platform.isAndroid);

    testWidgets(
        'replay recorder pause silences and resume restarts frames on Android',
        (tester) async {
      await setupSentryAndApp(tester);
      final native = SentryFlutter.native as SentryNativeJava?;
      expect(native, isNotNull);

      await Future.delayed(const Duration(seconds: 2));
      final recorder = native!.testRecorder!;

      var frameCount = 0;
      final firstFrame = Completer<void>();
      recorder.onScreenshotAddedForTest = () {
        frameCount++;
        if (!firstFrame.isCompleted) firstFrame.complete();
      };

      await recorder
          .onConfigurationChanged(const ScheduledScreenshotRecorderConfig(
        width: 800,
        height: 600,
        frameRate: 1,
      ));

      await tester.pump();
      await firstFrame.future.timeout(const Duration(seconds: 5));

      await recorder.pause();
      await tester.pump();
      final pausedCount = frameCount;
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(frameCount, equals(pausedCount));

      await recorder.resume();
      await tester.pump();
      final resumedBaseline = frameCount;
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(frameCount, greaterThan(resumedBaseline));

      await recorder.stop();
      await tester.pump();
      final afterStopCount = frameCount;
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(frameCount, equals(afterStopCount));
    }, skip: !Platform.isAndroid);

    testWidgets('setReplayConfig applies without error on Android',
        (tester) async {
      await setupSentryAndApp(tester);
      const config = ReplayConfig(
        windowWidth: 1080,
        windowHeight: 1920,
        width: 800,
        height: 600,
        frameRate: 1,
      );
      await Future.delayed(const Duration(seconds: 2));

      // Should not throw
      await SentryFlutter.native?.setReplayConfig(config);
    }, skip: !Platform.isAndroid);
  });
}
