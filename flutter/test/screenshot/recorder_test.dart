// For some reason, this test is not working in the browser but that's OK, we
// don't support video recording anyway.
@TestOn('vm')
library dart_test;

import 'dart:ui';

import 'package:flutter/widgets.dart' as widgets;
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/replay/replay_recorder.dart';
import 'package:sentry_flutter/src/screenshot/recorder.dart';
import 'package:sentry_flutter/src/screenshot/recorder_config.dart';

import '../mocks.dart';
import 'test_widget.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // with `tester.binding.setSurfaceSize` you are setting the `logical resolution`
  // not the `device screen resolution`.
  // The `device screen resolution = logical resolution * devicePixelRatio`

  testWidgets('captures full resolution images - portrait', (tester) async {
    await tester.binding.setSurfaceSize(Size(2000, 4000));
    final fixture = await _Fixture.create(tester);

    //devicePixelRatio is 3.0 therefore the resolution multiplied by 3
    expect(await fixture.capture(), '6000x12000');
  });

  testWidgets('captures full resolution images - landscape', (tester) async {
    await tester.binding.setSurfaceSize(Size(4000, 2000));
    final fixture = await _Fixture.create(tester);

    //devicePixelRatio is 3.0 therefore the resolution multiplied by 3
    expect(await fixture.capture(), '12000x6000');
  });

  testWidgets('captures high resolution images - portrait', (tester) async {
    await tester.binding.setSurfaceSize(Size(2000, 4000));
    final targetResolution = SentryScreenshotQuality.high.targetResolution();
    final fixture = await _Fixture.create(tester,
        width: targetResolution, height: targetResolution);

    expect(await fixture.capture(), '960x1920');
  });

  testWidgets('captures high resolution images - landscape', (tester) async {
    await tester.binding.setSurfaceSize(Size(4000, 2000));
    final targetResolution = SentryScreenshotQuality.high.targetResolution();
    final fixture = await _Fixture.create(tester,
        width: targetResolution, height: targetResolution);

    expect(await fixture.capture(), '1920x960');
  });

  testWidgets('captures medium resolution images', (tester) async {
    await tester.binding.setSurfaceSize(Size(2000, 4000));
    final targetResolution = SentryScreenshotQuality.medium.targetResolution();
    final fixture = await _Fixture.create(tester,
        width: targetResolution, height: targetResolution);

    expect(await fixture.capture(), '640x1280');
  });

  testWidgets('captures low resolution images', (tester) async {
    await tester.binding.setSurfaceSize(Size(2000, 4000));
    final targetResolution = SentryScreenshotQuality.low.targetResolution();
    final fixture = await _Fixture.create(tester,
        width: targetResolution, height: targetResolution);

    expect(await fixture.capture(), '427x854');
  });

  testWidgets('propagates errors in test-mode', (tester) async {
    final fixture = await _Fixture.create(tester);
    fixture.options
      ..automatedTestMode = true
      ..experimental.privacy.maskCallback<widgets.Stack>((el, widget) {
        throw Exception('testing masking error');
      });

    expect(
        fixture.capture,
        throwsA(predicate(
            (Exception e) => e.toString().contains('testing masking error'))));
  });

  testWidgets('does not propagate errors in real apps', (tester) async {
    final fixture = await _Fixture.create(tester);
    fixture.options
      ..automatedTestMode = false
      ..experimental.privacy.maskCallback<widgets.Stack>((el, widget) {
        throw Exception('testing masking error');
      });

    expect(await fixture.capture(), isNull);
  });

  // TODO: remove in the next major release, see _SentryFlutterExperimentalOptions.
  group('Widget filter is used based on config or application', () {
    test('Uses widget filter by default for Replay', () {
      final sut = ReplayScreenshotRecorder(
        ScreenshotRecorderConfig(),
        defaultTestOptions(),
      );
      expect(sut.hasWidgetFilter, isTrue);
    });

    test('Does not use widget filter by default for Screenshots', () {
      final sut =
          ScreenshotRecorder(ScreenshotRecorderConfig(), defaultTestOptions());
      expect(sut.hasWidgetFilter, isFalse);
    });

    test(
        'Uses widget filter for Screenshots when privacy configured explicitly',
        () {
      final sut = ScreenshotRecorder(ScreenshotRecorderConfig(),
          defaultTestOptions()..experimental.privacy.maskAllText = false);
      expect(sut.hasWidgetFilter, isTrue);
    });
  });
}

class _Fixture {
  late final ScreenshotRecorder sut = ScreenshotRecorder(
      ScreenshotRecorderConfig(width: width, height: height), options);
  late final options = defaultTestOptions()
    ..bindingUtils = TestBindingWrapper();
  final double? width;
  final double? height;

  _Fixture({this.width, this.height});

  static Future<_Fixture> create(WidgetTester tester,
      {double? width, double? height}) async {
    final fixture = _Fixture(width: width, height: height);
    await pumpTestElement(tester);
    return fixture;
  }

  Future<String?> capture() => sut.capture<String?>((screenshot) {
        return Future.value("${screenshot.width}x${screenshot.height}");
      });
}
