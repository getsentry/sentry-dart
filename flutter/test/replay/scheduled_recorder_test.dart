// For some reason, this test is not working in the browser but that's OK, we
// don't support video recording anyway.
@TestOn('vm')
library dart_test;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/replay/scheduled_recorder.dart';
import 'package:sentry_flutter/src/replay/scheduled_recorder_config.dart';

import '../mocks.dart';
import '../screenshot/test_widget.dart';

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
}

class _Fixture {
  final WidgetTester _tester;
  late final ScheduledScreenshotRecorder sut;
  final capturedImages = <String>[];
  late Completer<void> _completer;

  _Fixture._(this._tester) {
    sut = ScheduledScreenshotRecorder(
      ScheduledScreenshotRecorderConfig(
        width: 1000,
        height: 1000,
        frameRate: 1000,
      ),
      defaultTestOptions()..bindingUtils = TestBindingWrapper(),
      (image, isNewlyCaptured) async {
        capturedImages.add('${image.width}x${image.height}');
        if (!_completer.isCompleted) {
          _completer.complete();
        }
      },
    );
  }

  static Future<_Fixture> create(WidgetTester tester) async {
    final fixture = _Fixture._(tester);
    await pumpTestElement(tester);
    fixture.sut.start();
    return fixture;
  }

  Future<void> nextFrame(bool imageIsExpected) async {
    _completer = Completer();
    _tester.binding.scheduleFrame();
    await _tester.pumpAndSettle(const Duration(seconds: 1));
    await _tester.idle();
    await _completer.future
        .timeout(const Duration(seconds: 1),
        onTimeout: imageIsExpected ? null : () {});
  }
}
