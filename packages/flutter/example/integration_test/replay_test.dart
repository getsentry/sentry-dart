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
import 'package:sentry_flutter/src/native/cocoa/sentry_native_cocoa.dart';
import 'package:sentry_flutter/src/native/java/android_replay_recorder.dart';
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

    testWidgets('sets replay ID to context (Android/iOS)', (tester) async {
      await setupSentryAndApp(tester);

      if (Platform.isAndroid) {
        final native = SentryFlutter.native as SentryNativeJava?;
        expect(native, isNotNull);
        await native!.testSetReplayId('123', replayIsBuffering: false);
      } else if (Platform.isIOS) {
        final native = SentryFlutter.native as SentryNativeCocoa?;
        expect(native, isNotNull);
        await native!.testSetReplayId('123', replayIsBuffering: false);
      } else {
        return;
      }

      await Sentry.configureScope((scope) async {
        expect(scope.replayId?.toString(), '123');
      });
    });

    testWidgets('clears replay ID from context (Android only)', (tester) async {
      if (!Platform.isAndroid) return;
      await setupSentryAndApp(tester);

      final native = SentryFlutter.native as SentryNativeJava?;
      expect(native, isNotNull);
      await native!.testSetReplayId('123', replayIsBuffering: false);

      await Sentry.configureScope((scope) async {
        expect(scope.replayId, isNotNull);
      });

      await native.testClearReplayId();

      await Sentry.configureScope((scope) async {
        expect(scope.replayId, isNull);
      });
    });

    testWidgets('Android: captures images and pause/resume/stop',
        (tester) async {
      if (!Platform.isAndroid) return;
      await setupSentryAndApp(tester);
      final native = SentryFlutter.native as SentryNativeJava?;
      expect(native, isNotNull);
      final recorder = native!.testRecorder;

      // Configure recorder
      await recorder
          .onConfigurationChanged(const ScheduledScreenshotRecorderConfig(
        width: 800,
        height: 600,
        frameRate: 1,
      ));

      var count = 0;
      final completer = Completer<void>();
      AndroidReplayRecorder.onScreenshotAddedForTest = () {
        count++;
        if (!completer.isCompleted) completer.complete();
      };

      // Start and wait for first frame
      await recorder.start();
      await completer.future;
      expect(count > 0, isTrue);

      // Pause and ensure count is stable
      final pausedAt = count;
      await recorder.pause();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(count, equals(pausedAt));

      // Resume and ensure count increases
      await recorder.resume();
      final resumedCompleter = Completer<void>();
      final startCount = count;
      AndroidReplayRecorder.onScreenshotAddedForTest = () {
        count++;
        if (!resumedCompleter.isCompleted && count > startCount) {
          resumedCompleter.complete();
        }
      };
      await resumedCompleter.future;
      expect(count, greaterThan(startCount));

      // Stop and ensure no further increments
      await recorder.stop();
      final stoppedAt = count;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(count, equals(stoppedAt));
      AndroidReplayRecorder.onScreenshotAddedForTest = null;
    });

    testWidgets('Android: setReplayConfig applies without error',
        (tester) async {
      if (!Platform.isAndroid) return;
      await setupSentryAndApp(tester);
      const config = ReplayConfig(
        windowWidth: 1080,
        windowHeight: 1920,
        width: 800,
        height: 600,
        frameRate: 1,
      );
      // Should not throw
      await SentryFlutter.native?.setReplayConfig(config);
    });

    testWidgets('iOS: capture screenshot via test recorder returns metadata',
        (tester) async {
      if (!Platform.isIOS) return;
      await setupSentryAndApp(tester);
      final native = SentryFlutter.native as SentryNativeCocoa?;
      expect(native, isNotNull);
      final json = await native!.testRecorder.captureScreenshot();
      expect(json, isNotNull);
      expect(json!['length'], isNotNull);
      expect(json['address'], isNotNull);
      expect(json['width'], isNotNull);
      expect(json['height'], isNotNull);
      expect((json['width'] as int) > 0, isTrue);
      expect((json['height'] as int) > 0, isTrue);

      // Also verify capture works with null replayId
      await (SentryFlutter.native as SentryNativeCocoa)
          .testSetReplayId(null, replayIsBuffering: false);
      final json2 = await native.testRecorder.captureScreenshot();
      expect(json2, isNotNull);
    });
  });
}
