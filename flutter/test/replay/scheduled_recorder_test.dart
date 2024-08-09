// For some reason, this test is not working in the browser but that's OK, we
// don't support video recording anyway.
@TestOn('vm')
library dart_test;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/replay/scheduled_recorder.dart';
import 'package:sentry_flutter/src/replay/recorder_config.dart';

import '../mocks.dart';
import 'test_widget.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures images', (tester) async {
    final fixture = await _Fixture.create(tester);
    expect(fixture.capturedImages, isEmpty);
    await fixture.nextFrame();
    expect(fixture.capturedImages, ['1000x750']);
    await fixture.nextFrame();
    expect(fixture.capturedImages, ['1000x750', '1000x750']);
    final stopFuture = fixture.sut.stop();
    await fixture.nextFrame();
    await stopFuture;
    expect(fixture.capturedImages, ['1000x750', '1000x750']);
  });
}

class _Fixture {
  final WidgetTester _tester;
  late final ScheduledScreenshotRecorder sut;
  final capturedImages = <String>[];

  _Fixture._(this._tester) {
    sut = ScheduledScreenshotRecorder(
      ScheduledScreenshotRecorderConfig(
        width: 1000,
        height: 1000,
        frameRate: 1000,
      ),
      (Image image) async {
        capturedImages.add("${image.width}x${image.height}");
      },
      SentryFlutterOptions()..bindingUtils = TestBindingWrapper(),
    );
  }

  static Future<_Fixture> create(WidgetTester tester) async {
    final fixture = _Fixture._(tester);
    await pumpTestElement(tester);
    fixture.sut.start();
    return fixture;
  }

  Future<void> nextFrame() async {
    _tester.binding.scheduleFrame();
    await _tester.pumpAndSettle(const Duration(seconds: 1));
  }
}
