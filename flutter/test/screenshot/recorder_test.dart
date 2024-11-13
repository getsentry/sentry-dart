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

  testWidgets('captures full resolution images - landscape', (tester) async {
    final fixture = await _Fixture.create(tester);

    expect(fixture.capture(), completion('2400x1800'));
  });

  testWidgets('captures high resolution images - portrait', (tester) async {
    await tester.binding.setSurfaceSize(Size(2000, 4000));
    final targetResolution = SentryScreenshotQuality.high.targetResolution();
    final fixture = await _Fixture.create(tester,
        width: targetResolution, height: targetResolution);

    expect(fixture.capture(), completion('960x1920'));
  });

  testWidgets('captures high resolution images - landscape', (tester) async {
    await tester.binding.setSurfaceSize(Size(4000, 2000));
    final targetResolution = SentryScreenshotQuality.high.targetResolution();
    final fixture = await _Fixture.create(tester,
        width: targetResolution, height: targetResolution);

    expect(fixture.capture(), completion('1920x960'));
  });

  testWidgets('captures medium resolution images', (tester) async {
    await tester.binding.setSurfaceSize(Size(2000, 4000));
    final targetResolution = SentryScreenshotQuality.medium.targetResolution();
    final fixture = await _Fixture.create(tester,
        width: targetResolution, height: targetResolution);

    expect(fixture.capture(), completion('640x1280'));
  });

  testWidgets('captures low resolution images', (tester) async {
    await tester.binding.setSurfaceSize(Size(2000, 4000));
    final targetResolution = SentryScreenshotQuality.low.targetResolution();
    final fixture = await _Fixture.create(tester,
        width: targetResolution, height: targetResolution);

    expect(fixture.capture(), completion('427x854'));
  });

  // TODO: remove in the next major release, see _SentryFlutterExperimentalOptions.
  group('Widget filter is used based on config or application', () {
    test('Uses widget filter by default for Replay', () {
      final sut = ScreenshotRecorder(
        ScreenshotRecorderConfig(),
        defaultTestOptions(),
      );
      expect(sut.hasWidgetFilter, isTrue);
    });

    test('Does not use widget filter by default for Screenshots', () {
      final sut = ScreenshotRecorder(
          ScreenshotRecorderConfig(), defaultTestOptions(),
          isReplayRecorder: false);
      expect(sut.hasWidgetFilter, isFalse);
    });

    test(
        'Uses widget filter for Screenshots when privacy configured explicitly',
        () {
      final sut = ScreenshotRecorder(ScreenshotRecorderConfig(),
          defaultTestOptions()..experimental.privacy.maskAllText = false,
          isReplayRecorder: false);
      expect(sut.hasWidgetFilter, isTrue);
    });
  });
}

class _Fixture {
  late final ScreenshotRecorder sut;

  _Fixture({int? width, int? height}) {
    sut = ScreenshotRecorder(
      ScreenshotRecorderConfig(width: width, height: height),
      defaultTestOptions()..bindingUtils = TestBindingWrapper(),
    );
  }

  static Future<_Fixture> create(WidgetTester tester,
      {int? width, int? height}) async {
    final fixture = _Fixture(width: width, height: height);
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
