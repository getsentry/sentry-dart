// Runs on the VM: like the other replay recorder tests, capturing doesn't
// work in the browser test runner. The browser side is covered by the
// canvas bridge tests.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/replay/scheduled_recorder_config.dart';
import 'package:sentry_flutter/src/web/replay/sentry_web_replay_recorder.dart';
import 'package:sentry_flutter/src/web/replay/web_replay_canvas_bridge.dart';

import '../../mocks.dart';
import '../../replay/replay_test_util.dart';
import '../../screen_capture/test_widget.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('$SentryWebReplayRecorder', () {
    testWidgets('feeds captured frame to the bridge', (tester) async {
      await tester.runAsync(() async {
        final fixture = await _Fixture.create(tester);

        await fixture.nextFrame();

        expect(fixture.bridge.startCalls, 1);
        expect(fixture.bridge.updatePositionCalls, hasLength(1));
        expect(fixture.bridge.feedFrameCalls, hasLength(1));
        final fed = fixture.bridge.feedFrameCalls.single;
        expect(fed.width, greaterThan(0));
        expect(fed.height, greaterThan(0));

        await fixture.sut.stop();
      });
    });

    testWidgets(
      'config changes while running keep the capture cadence and apply on the next scheduled capture',
      (tester) async {
        await tester.runAsync(() async {
          final fixture = await _Fixture.create(tester, frameRate: 1);
          await fixture.nextFrame();

          // A window drag: one config change per frame.
          for (final size in [800.0, 600.0, 100.0]) {
            await fixture.sut.onConfigurationChanged(
              ScheduledScreenshotRecorderConfig(
                width: size,
                height: size,
                frameRate: 1,
              ),
            );
          }
          // A restarted scheduler captures on the very next frame; the kept
          // cadence waits out the frame interval (1s at 1 fps). The wait gives
          // an immediate capture time to land, well short of the interval.
          await fixture.renderFrame();
          await fixture.renderFrame();
          await Future<void>.delayed(const Duration(milliseconds: 100));
          expect(fixture.bridge.feedFrameCalls, hasLength(1));

          await fixture.nextFrame();

          expect(
            fixture.bridge.feedFrameCalls[1].width,
            lessThanOrEqualTo(100),
          );

          await fixture.sut.stop();
        });
      },
    );

    // E.g. the JS replay wasn't sampled, or stopped itself on session expiry.
    testWidgets('does not capture while the JS replay is not recording', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final fixture = await _Fixture.create(tester);
        fixture.recording = false;

        await fixture.renderFrame();
        await fixture.renderFrame();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(fixture.bridge.feedFrameCalls, isEmpty);

        fixture.recording = true;
        await fixture.nextFrame();
        expect(fixture.bridge.feedFrameCalls, hasLength(1));

        await fixture.sut.stop();
      });
    });

    testWidgets('stops the bridge on stop', (tester) async {
      await tester.runAsync(() async {
        final fixture = await _Fixture.create(tester);
        await fixture.nextFrame();

        await fixture.sut.stop();

        expect(fixture.bridge.stopCalls, 1);
      });
    });
  });
}

class _FeedFrameCall {
  _FeedFrameCall(this.rgba, this.width, this.height);
  final Uint8List rgba;
  final int width;
  final int height;
}

class _FakeWebReplayCanvasBridge implements WebReplayCanvasBridge {
  int startCalls = 0;
  int stopCalls = 0;
  final updatePositionCalls = <(Rect, double)>[];
  final feedFrameCalls = <_FeedFrameCall>[];
  void Function()? onFeedFrame;

  @override
  void start() => startCalls++;

  @override
  void updatePosition(Rect rect, double devicePixelRatio) =>
      updatePositionCalls.add((rect, devicePixelRatio));

  @override
  void feedFrame(Uint8List rgba, int width, int height) {
    feedFrameCalls.add(_FeedFrameCall(rgba, width, height));
    onFeedFrame?.call();
  }

  @override
  void stop() => stopCalls++;
}

class _Fixture {
  final WidgetTester _tester;
  late final SentryWebReplayRecorder _sut;
  final bridge = _FakeWebReplayCanvasBridge();
  var _completer = Completer<void>();
  var recording = true;

  SentryWebReplayRecorder get sut => _sut;

  _Fixture._(this._tester, int frameRate) {
    _sut = SentryWebReplayRecorder(
      defaultTestOptions()..bindingUtils = TestBindingWrapper(),
      bridge: bridge,
      isRecording: () => recording,
    );
    bridge.onFeedFrame = () {
      if (!_completer.isCompleted) _completer.complete();
    };

    _sut.onConfigurationChanged(
      ScheduledScreenshotRecorderConfig(
        width: 1000,
        height: 1000,
        frameRate: frameRate,
      ),
    );
  }

  static Future<_Fixture> create(
    WidgetTester tester, {
    int frameRate = 1000,
  }) async {
    final fixture = _Fixture._(tester, frameRate);
    await pumpTestElement(tester);
    await fixture.sut.start();
    return fixture;
  }

  Future<void> nextFrame() async {
    _completer = Completer();
    _tester.binding.scheduleFrame();
    await _tester.pumpAndWaitUntil(_completer.future);
  }

  Future<void> renderFrame() async {
    _tester.binding.scheduleFrame();
    await _tester.pump();
  }
}
