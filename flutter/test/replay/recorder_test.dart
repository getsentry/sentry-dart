// For some reason, this test is not working in the browser but that's OK, we
// don't support video recording anyway.
@TestOn('vm')
library dart_test;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/replay/recorder.dart';
import 'package:sentry_flutter/src/replay/recorder_config.dart';

import '../mocks.dart';
import 'test_widget.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures images', (tester) async {
    final fixture = await _Fixture.create(tester);
    expect(fixture.capture(), completion('800x600'));
  });
}

class _Fixture {
  late final ScreenshotRecorder sut;

  _Fixture._() {
    sut = ScreenshotRecorder(
      ScreenshotRecorderConfig(),
      defaultTestOptions()..bindingUtils = TestBindingWrapper(),
    );
  }

  static Future<_Fixture> create(WidgetTester tester) async {
    final fixture = _Fixture._();
    await pumpTestElement(tester);
    return fixture;
  }

  Future<String?> capture() async {
    String? captured;
    await sut.capture((Image image) async {
      captured = "${image.width}x${image.height}";
    });
    return captured;
  }
}
