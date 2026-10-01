// For some reason, this test is not working in the browser but that's OK, we
// don't support video recording anyway.
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
import '../../screenshot/test_widget.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('stops the bridge on stop', (tester) async {
    await tester.runAsync(() async {
      final fixture = await _Fixture.create(tester);
      await fixture.nextFrame();

      await fixture.sut.stop();

      expect(fixture.bridge.stopCalls, 1);
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
  late Completer<void> _completer;

  SentryWebReplayRecorder get sut => _sut;

  _Fixture._(this._tester) {
    _sut = SentryWebReplayRecorder(
      defaultTestOptions()..bindingUtils = TestBindingWrapper(),
      bridge: bridge,
    );
    bridge.onFeedFrame = () => _completer.complete();

    _sut.onConfigurationChanged(ScheduledScreenshotRecorderConfig(
      width: 1000,
      height: 1000,
      frameRate: 1000,
    ));
  }

  static Future<_Fixture> create(WidgetTester tester) async {
    final fixture = _Fixture._(tester);
    await pumpTestElement(tester);
    await fixture.sut.start();
    return fixture;
  }

  Future<void> nextFrame() async {
    _completer = Completer();
    _tester.binding.scheduleFrame();
    await _tester.pumpAndWaitUntil(_completer.future);
  }
}
