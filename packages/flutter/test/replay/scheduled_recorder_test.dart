// For some reason, this test is not working in the browser but that's OK, we
// don't support video recording anyway.
@TestOn('vm')
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/replay/scheduled_recorder.dart';
import 'package:sentry_flutter/src/replay/scheduled_recorder_config.dart';

import '../mocks.dart';
import '../screenshot/test_widget.dart';
import 'replay_test_util.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures images on frame updates', (tester) async {
    await tester.runAsync(() async {
      final fixture = await _Fixture.create(tester);
      expect(fixture.capturedImages, isEmpty);
      await fixture.nextFrame(true);
      expect(fixture.capturedImages, ['1000x750']);
      await fixture.nextFrame(true);
      expect(fixture.capturedImages, ['1000x750', '1000x750']);
      final stopFuture = fixture.sut.stop();
      await fixture.nextFrame(false);
      await stopFuture;
      expect(fixture.capturedImages, ['1000x750', '1000x750']);
    });
  });

  testWidgets('skips capture while app is not resumed', (tester) async {
    await tester.runAsync(() async {
      final fixture = await _Fixture.create(tester);
      await fixture.nextFrame(true);
      expect(fixture.capturedImages, ['1000x750']);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await fixture.nextFrame(false);
      expect(fixture.capturedImages, ['1000x750']);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await fixture.nextFrame(true);
      expect(fixture.capturedImages, ['1000x750', '1000x750']);

      final stopFuture = fixture.sut.stop();
      await fixture.nextFrame(false);
      await stopFuture;
    });
  });
}

class _Fixture {
  final WidgetTester _tester;
  late final ScheduledScreenshotRecorder _sut;
  final capturedImages = <String>[];
  late Completer<void> _completer;

  ScheduledScreenshotRecorder get sut => _sut;

  _Fixture._(this._tester) {
    _sut = ScheduledScreenshotRecorder(
      defaultTestOptions()..bindingUtils = TestBindingWrapper(),
      (image, isNewlyCaptured) async {
        capturedImages.add('${image.width}x${image.height}');
        _completer.complete();
      },
    );

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

  Future<void> nextFrame(bool imageIsExpected) async {
    _completer = Completer();
    _tester.binding.scheduleFrame();
    await _tester.pumpAndWaitUntil(_completer.future,
        requiredToComplete: imageIsExpected);
    expect(_completer.isCompleted, imageIsExpected);
  }
}
