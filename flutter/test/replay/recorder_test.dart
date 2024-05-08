// For some reason, this test is not working in the browser but that's OK, we
// don't support video recording anyway.
@TestOn('vm')

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/replay/recorder.dart';
import 'package:sentry_flutter/src/replay/recorder_config.dart';

import '../mocks.dart';
import 'test_widget.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures images', (tester) async {
    await tester.runAsync(() async {
      await getTestElement(tester);
      final fixture = _Fixture();
      expect(fixture.capturedImages, isEmpty);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(fixture.capturedImages, ['1000x750']);
    });
  });
}

class _Fixture {
  late final ScreenshotRecorder sut;
  final capturedImages = <String>[];

  _Fixture() {
    sut = ScreenshotRecorder(
      ScreenshotRecorderConfig(
        width: 1000,
        height: 1000,
        frameRate: 1000,
      ),
      (Image image) async {
        capturedImages.add("${image.width}x${image.height}");
      },
      SentryFlutterOptions()..bindingUtils = TestBindingWrapper(),
    );
    sut.start();
  }
}
