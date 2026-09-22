// ignore_for_file: invalid_use_of_internal_member

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/java/binding.dart' as native;
import 'package:sentry_flutter/src/native/java/sentry_native_java.dart';
import 'package:sentry_flutter/src/replay/replay_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('Android replay configuration', () {
    late Fixture fixture;
    setUp(() => fixture = Fixture());
    tearDown(() async {
      await Sentry.close();
      fixture.dispose();
    });

    testWidgets('before startup reaches the native recorder', (tester) async {
      await fixture.getSut(tester);
      await fixture.stop(tester);
      await fixture.mount(tester);
      final builds = fixture.widgetBuilds;
      await fixture.start(tester);
      await fixture.waitForFrame(tester);
      expect(fixture.widgetBuilds, builds,
          reason: 'Recording must not depend on another root widget build');
    });

    testWidgets('after startup reaches the native recorder', (tester) async {
      await fixture.getSut(tester);
      await fixture.mount(tester);
      await fixture.waitForFrame(tester);
    });

    testWidgets('survives recorder replacement without a widget rebuild',
        (tester) async {
      await fixture.getSut(tester);
      await fixture.mount(tester);
      await fixture.waitForFrame(tester);
      final previousDirectory = fixture.replayDirectory!.path;
      final builds = fixture.widgetBuilds;
      await fixture.stop(tester);
      await fixture.start(tester);
      await fixture.waitForFrame(tester);
      expect(fixture.replayDirectory!.path, isNot(previousDirectory));
      expect(fixture.widgetBuilds, builds);
    });

    testWidgets('retains the latest valid size across startup', (tester) async {
      await fixture.getSut(tester);
      await fixture.stop(tester);
      await fixture.mount(tester);
      fixture.binding.setReplayConfig(const ReplayConfig(
          windowWidth: 160, windowHeight: 320, width: 96, height: 192));
      fixture.binding.setReplayConfig(const ReplayConfig(
          windowWidth: 160, windowHeight: 320, width: 173, height: 346));
      fixture.binding.setReplayConfig(const ReplayConfig(
          windowWidth: 0, windowHeight: 0, width: 0, height: 0));
      await fixture.start(tester);
      await fixture.waitForFrame(tester);
      final codec = await ui
          .instantiateImageCodec(await fixture.frames.first.readAsBytes());
      final frame = await codec.getNextFrame();
      try {
        expect((frame.image.width, frame.image.height), (176, 352));
      } finally {
        frame.image.dispose();
        codec.dispose();
      }
    });

    testWidgets('does not reuse configuration after close and reinitialize',
        (tester) async {
      await fixture.getSut(tester);
      await fixture.mount(tester);
      await fixture.waitForFrame(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      final previousBinding = fixture.binding;
      await Sentry.close();
      fixture.dispose();
      await fixture.getSut(tester);
      expect(fixture.binding, isNot(same(previousBinding)));
      // Keep capture possible but suppress new config delivery from the widget.
      SentryScreenshotWidget.reset();
      await fixture.mount(tester);
      // Explicitly restart too: stale config must not be restored by replayStarted.
      await fixture.stop(tester);
      await fixture.start(tester);
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (DateTime.now().isBefore(deadline)) {
        expect(fixture.frames, isEmpty);
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      fixture.binding.setReplayConfig(const ReplayConfig(
          windowWidth: 160, windowHeight: 320, width: 160, height: 320));
      await fixture.waitForFrame(tester);
    });
  }, skip: !Platform.isAndroid);
}

class Fixture {
  late SentryNativeJava binding;
  native.ReplayIntegration? _replay;
  int widgetBuilds = 0;
  native.ReplayIntegration get replay => _replay!;

  Future<SentryNativeJava> getSut(WidgetTester tester) async {
    await SentryFlutter.init((options) {
      options.dsn = 'http://public@127.0.0.1:9/1';
      options.replay.sessionSampleRate = 1.0;
      options.replay.onErrorSampleRate = 1.0;
      options.replay.quality = SentryReplayQuality.high;
    });
    binding = SentryFlutter.native as SentryNativeJava;
    _replay = native.SentryFlutterPlugin.privateSentryGetReplayIntegration();
    expect(_replay, isNotNull);
    await waitUntil(
        tester,
        () => replay.isRecording() && binding.testRecorder != null,
        'initial replay startup');
    return binding;
  }

  Future<void> mount(WidgetTester tester) async {
    SentryScreenshotWidget.onBuild((_, __) {
      widgetBuilds++;
      return true;
    });
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 160,
          height: 320,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(160, 320)),
            child: SentryScreenshotWidget(
              child: const ColoredBox(color: Color(0xff336699)),
            ),
          ),
        ),
      ),
    ));
  }

  Future<void> stop(WidgetTester tester) async {
    replay.stop();
    await waitUntil(
        tester,
        () => !replay.isRecording() && binding.testRecorder == null,
        'replay stop callback');
  }

  Future<void> start(WidgetTester tester) async {
    replay.start();
    await waitUntil(
        tester,
        () => replay.isRecording() && binding.testRecorder != null,
        'replay start callback');
  }

  Directory? get replayDirectory {
    final file = replay.getReplayCacheDir();
    try {
      return file == null ? null : Directory(file.toString());
    } finally {
      file?.release();
    }
  }

  List<File> get frames {
    final directory = replayDirectory;
    if (directory == null || !directory.existsSync()) return [];
    return directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.jpg') && file.lengthSync() > 0)
        .toList();
  }

  Future<void> waitForFrame(WidgetTester tester) => waitUntil(
      tester,
      () => frames.isNotEmpty,
      'a JPEG frame in the active native replay cache');

  Future<void> waitUntil(WidgetTester tester, bool Function() condition,
      String description) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Timed out waiting for $description');
      }
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  void dispose() {
    _replay?.release();
    _replay = null;
  }
}
