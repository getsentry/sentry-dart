// ignore_for_file: invalid_use_of_internal_member

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('Cocoa Replay', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    tearDown(() async {
      await Sentry.close();
    });

    testWidgets('keeps an unflushed buffer off the scope', (tester) async {
      final replay = await fixture.getSut(tester);

      await replay.startBuffering();
      await fixture.waitForScreenshot();

      expect(Sentry.currentHub.scope.replayId, isNull);
      expect(SentryFlutter.native?.replayId, isNotNull);
      await fixture.expectLogReplay(isBuffering: true);
    }, skip: !Platform.isIOS);

    testWidgets('links the scope after flushing a buffer', (tester) async {
      final replay = await fixture.getSut(tester);
      await replay.startBuffering();
      await fixture.waitForScreenshot();
      expect(Sentry.currentHub.scope.replayId, isNull);
      final bufferedReplayId = SentryFlutter.native?.replayId;
      expect(bufferedReplayId, isNotNull);

      await replay.flush();
      await fixture.waitFor(
        () => Sentry.currentHub.scope.replayId != null,
        'Flushing the buffer did not set the scope replay ID',
      );
      final replayId = Sentry.currentHub.scope.replayId;
      expect(replayId, isNot(const SentryId.empty()));
      expect(SentryFlutter.native?.replayId, replayId);
      expect(replayId, bufferedReplayId);
      await fixture.expectLogReplay(isBuffering: false);

      await replay.stop();
      final screenshotCount = fixture.channel.screenshotCount;
      await replay.startBuffering();
      await fixture.waitForScreenshot(after: screenshotCount);
      await fixture.waitFor(
        () =>
            SentryFlutter.native?.replayId != null &&
            SentryFlutter.native?.replayId != bufferedReplayId,
        'Restarting the buffer did not provide a new replay ID',
      );

      expect(Sentry.currentHub.scope.replayId, isNull);
      expect(SentryFlutter.native?.replayId, isNotNull);
      expect(SentryFlutter.native?.replayId, isNot(bufferedReplayId));
      await fixture.expectLogReplay(isBuffering: true);
    }, skip: !Platform.isIOS);
  });
}

class Fixture {
  final channel = ReplayScreenshotChannel();
  late SentryFlutterOptions options;

  Future<SentryReplay> getSut(WidgetTester tester) async {
    await SentryFlutter.init((options) {
      this.options = options;
      options
        ..dsn = 'https://abc@def.ingest.sentry.io/1234567'
        ..automatedTestMode = true;
      options.replay
        ..sessionSampleRate = 0
        ..onErrorSampleRate = 0;
    }, options: SentryFlutterOptions()..methodChannel = channel);
    await tester.pumpWidget(
      SentryWidget(
        child: const MaterialApp(home: Scaffold(body: Text('Replay test'))),
      ),
    );
    await tester.pump();
    return SentryFlutter.replay;
  }

  Future<void> expectLogReplay({required bool isBuffering}) async {
    final log = SentryLog(
      timestamp: options.clock(),
      traceId: SentryId.newId(),
      level: SentryLogLevel.info,
      body: 'Cocoa replay',
      attributes: {},
    );
    await options.lifecycleRegistry.dispatchCallback(OnProcessLog(log, Hint()));
    expect(
      log.attributes['sentry.replay_id']?.value,
      SentryFlutter.native!.replayId.toString(),
    );
    expect(
      log.attributes['sentry._internal.replay_is_buffering']?.value,
      isBuffering ? true : null,
    );
  }

  Future<void> waitForScreenshot({int after = 0}) => waitFor(
    () => channel.screenshotCount > after,
    'Cocoa did not request a replay screenshot',
  );

  Future<void> waitFor(bool Function() condition, String failure) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail(failure);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }
}

// Observe the real native callbacks without replacing the screenshot handler.
class ReplayScreenshotChannel extends MethodChannel {
  ReplayScreenshotChannel() : super('sentry_flutter');

  int screenshotCount = 0;

  @override
  void setMethodCallHandler(
    Future<dynamic> Function(MethodCall call)? handler,
  ) {
    super.setMethodCallHandler(
      handler == null
          ? null
          : (call) async {
              final result = await handler(call);
              if (call.method == 'captureReplayScreenshot') screenshotCount++;
              return result;
            },
    );
  }
}
