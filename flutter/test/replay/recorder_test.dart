// For some reason, this test is not working in the browser but that's OK, we
// don't support video recording anyway.
@TestOn('vm')
library dart_test;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/screenshot/recorder.dart';
import 'package:sentry_flutter/src/screenshot/recorder_config.dart';

import '../mocks.dart';
import 'test_widget.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures images', (tester) async {
    final fixture = await _Fixture.create(tester);
    expect(fixture.capture(), completion('800x600'));
  });

  testWidgets('captures full resolution images - portrait', (tester) async {
    await tester.binding.setSurfaceSize(Size(2000, 4000));
    final fixture = await _Fixture.create(tester);
    expect(fixture.capture(), completion('2000x4000'));
  });

  testWidgets('captures full resolution images - landscape', (tester) async {
    await tester.binding.setSurfaceSize(Size(4000, 2000));
    final fixture = await _Fixture.create(tester);
    expect(fixture.capture(), completion('4000x2000'));
  });

  testWidgets('captures high resolution images - portrait', (tester) async {
    await tester.binding.setSurfaceSize(Size(2000, 4000));
    final fixture =
        await _Fixture.create(tester, quality: SentryScreenshotQuality.high);
    expect(fixture.capture(), completion('960x1920'));
  });

  testWidgets('captures high resolution images - landscape', (tester) async {
    await tester.binding.setSurfaceSize(Size(4000, 2000));
    final fixture =
        await _Fixture.create(tester, quality: SentryScreenshotQuality.high);
    expect(fixture.capture(), completion('1920x960'));
  });

  testWidgets('captures medium resolution images', (tester) async {
    await tester.binding.setSurfaceSize(Size(2000, 4000));
    final fixture =
        await _Fixture.create(tester, quality: SentryScreenshotQuality.medium);
    expect(fixture.capture(), completion('640x1280'));
  });

  testWidgets('captures low resolution images', (tester) async {
    await tester.binding.setSurfaceSize(Size(2000, 4000));
    final fixture =
        await _Fixture.create(tester, quality: SentryScreenshotQuality.low);
    expect(fixture.capture(), completion('427x854'));
  });
}

class _Fixture {
  late final ScreenshotRecorder sut;

  _Fixture({SentryScreenshotQuality quality = SentryScreenshotQuality.full}) {
    sut = ScreenshotRecorder(
      ScreenshotRecorderConfig(quality: quality),
      defaultTestOptions()..bindingUtils = TestBindingWrapper(),
    );
  }

  static Future<_Fixture> create(WidgetTester tester,
      {SentryScreenshotQuality quality = SentryScreenshotQuality.full}) async {
    final fixture = _Fixture(quality: quality);
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
