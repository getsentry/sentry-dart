// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/java/android_replay_recorder.dart';
import 'package:sentry_flutter/src/native/java/sentry_native_java.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('$SentryReplay', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    tearDown(() async {
      await Sentry.close();
    });

    testWidgets('captures frames when started after the widget builds', (
      tester,
    ) async {
      final replay = await fixture.getSut(tester);

      await replay.start();

      await fixture.expectFrame(tester);
    }, skip: !Platform.isAndroid);

    testWidgets('captures frames after stop and restart without resizing', (
      tester,
    ) async {
      final replay = await fixture.getSut(tester);
      await replay.start();
      final firstRecorder = await fixture.expectFrame(tester);
      final firstId = fixture.native.replayId;

      await replay.stop();
      await fixture.waitFor(
        () => fixture.native.testRecorder == null,
        'Replay recorder did not stop',
      );
      await replay.start();

      final secondRecorder = await fixture.expectFrame(tester);
      expect(secondRecorder, isNot(same(firstRecorder)));
      expect(fixture.native.replayId, isNot(firstId));
    }, skip: !Platform.isAndroid);

    testWidgets('captures frames when flushing without an active replay', (
      tester,
    ) async {
      final replay = await fixture.getSut(tester);

      await replay.flush();

      await fixture.expectFrame(tester);
      await fixture.expectTelemetry(
        fixture.native.replayId!,
        isBuffering: false,
      );
    }, skip: !Platform.isAndroid);

    testWidgets('links telemetry after flushing a manual buffer', (
      tester,
    ) async {
      final replay = await fixture.getSut(tester);
      await replay.startBuffering();
      await fixture.expectFrame(tester);
      final replayId = fixture.native.replayId!;
      expect(Sentry.currentHub.scope.replayId, isNull);
      await fixture.expectTelemetry(replayId, isBuffering: true);

      await replay.flush();

      await fixture.waitFor(
        () => Sentry.currentHub.scope.replayId == replayId,
        'Dart scope was not updated after flushing the replay buffer',
      );
      await fixture.expectTelemetry(replayId, isBuffering: false);
    }, skip: !Platform.isAndroid);

    testWidgets(
      'keeps the new buffer state when flush is followed by stop and restart',
      (tester) async {
        final replay = await fixture.getSut(tester);
        await replay.startBuffering();
        await fixture.expectFrame(tester);
        final oldId = fixture.native.replayId;

        await replay.flush();
        await replay.stop();
        await replay.startBuffering();

        await fixture.waitFor(
          () =>
              fixture.native.replayId != null &&
              fixture.native.replayId != oldId,
          'Restart did not create a new replay',
        );
        await fixture.expectFrame(tester);
        expect(Sentry.currentHub.scope.replayId, isNull);
        await fixture.expectTelemetry(
          fixture.native.replayId!,
          isBuffering: true,
        );
      },
      skip: !Platform.isAndroid,
    );

    testWidgets('links telemetry after error sampling rejects a buffer', (
      tester,
    ) async {
      final replay = await fixture.getSut(tester);
      await replay.startBuffering();
      await fixture.expectFrame(tester);
      final replayId = fixture.native.replayId!;
      // Zero error sampling deterministically exercises the native rejection
      // path also taken by an unsampled error with a fractional sample rate.
      expect(fixture.native.captureReplay(), const SentryId.empty());

      await replay.flush();

      await fixture.waitFor(
        () => Sentry.currentHub.scope.replayId == replayId,
        'Rejected error capture prevented manual buffer promotion',
      );
      await fixture.expectTelemetry(replayId, isBuffering: false);
    }, skip: !Platform.isAndroid);
  });
}

class Fixture {
  late SentryFlutterOptions options;
  SentryNativeJava get native => SentryFlutter.native as SentryNativeJava;

  Future<SentryReplay> getSut(WidgetTester tester) async {
    await SentryFlutter.init((options) {
      this.options = options;
      options
        ..dsn = 'https://abc@def.ingest.sentry.io/1234567'
        ..automatedTestMode = true;
      options.replay
        ..sessionSampleRate = 0
        ..onErrorSampleRate = 0;
    });
    await tester.pumpWidget(
      SentryWidget(
        child: const MaterialApp(home: Scaffold(body: Text('Replay test'))),
      ),
    );
    await tester.pump();
    return SentryFlutter.replay;
  }

  Future<void> waitFor(bool Function() condition, String failure) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail(failure);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> expectTelemetry(
    SentryId replayId, {
    required bool isBuffering,
  }) async {
    final log = SentryLog(
      timestamp: DateTime.now(),
      traceId: SentryId.newId(),
      level: SentryLogLevel.info,
      body: 'Manual replay',
      attributes: {},
    );
    final metric = SentryCounterMetric(
      timestamp: DateTime.now(),
      name: 'manual-replay',
      value: 1,
      traceId: SentryId.newId(),
      attributes: {},
    );
    final span = RecordingSentrySpanV2.root(
      name: 'manual-replay',
      traceId: SentryId.newId(),
      onSpanEnd: (_) async {},
      clock: options.clock,
      dscCreator: (span) => SentryTraceContextHeader(span.traceId, 'publicKey'),
      samplingDecision: SentryTracesSamplingDecision(true),
    );
    await options.lifecycleRegistry.dispatchCallback(OnProcessLog(log, Hint()));
    await options.lifecycleRegistry.dispatchCallback(
      OnProcessMetric(metric, Hint()),
    );
    await options.lifecycleRegistry.dispatchCallback(
      OnProcessSpan(span, Hint()),
    );
    for (final attributes in [
      log.attributes,
      metric.attributes,
      span.attributes,
    ]) {
      expect(
        attributes[SemanticAttributesConstants.sentryReplayId]?.value,
        replayId.toString(),
      );
      expect(
        attributes[SemanticAttributesConstants.sentryInternalReplayIsBuffering]
            ?.value,
        isBuffering ? true : null,
      );
    }
  }

  Future<AndroidReplayRecorder> expectFrame(WidgetTester tester) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (native.testRecorder == null) {
      if (DateTime.now().isAfter(deadline)) {
        fail('The Android replay recorder was not created');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final recorder = native.testRecorder!;
    final frame = Completer<void>();
    recorder.onScreenshotAddedForTest = () {
      if (!frame.isCompleted) frame.complete();
    };
    try {
      await tester.pump();
      await frame.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => fail('Manual replay did not capture a frame'),
      );
    } finally {
      recorder.onScreenshotAddedForTest = null;
    }
    return recorder;
  }
}
