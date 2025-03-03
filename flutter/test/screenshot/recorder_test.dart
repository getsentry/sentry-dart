// For some reason, this test is not working in the browser but that's OK, we
// don't support video recording anyway.
@TestOn('vm')
library;

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/widgets.dart' as widgets;
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/screenshot/recorder.dart';
import 'package:sentry_flutter/src/screenshot/recorder_config.dart';
import 'package:sentry_flutter/src/screenshot/screenshot.dart';

import '../mocks.dart';
import 'test_widget.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // with `tester.binding.setSurfaceSize` you are setting the `logical resolution`
  // not the `device screen resolution`.
  // The `device screen resolution = logical resolution * devicePixelRatio`

  testWidgets('captures full resolution images - portrait', (tester) async {
    await tester.runAsync(() async {
      await tester.binding.setSurfaceSize(Size(20, 40));
      final fixture = await _Fixture.create(tester);

      //devicePixelRatio is 3.0 therefore the resolution multiplied by 3
      expect(await fixture.capture(), '60x120');
    });
  });

  testWidgets('captures full resolution images - landscape', (tester) async {
    await tester.runAsync(() async {
      await tester.binding.setSurfaceSize(Size(40, 20));
      final fixture = await _Fixture.create(tester);

      //devicePixelRatio is 3.0 therefore the resolution multiplied by 3
      expect(await fixture.capture(), '120x60');
    });
  });

  testWidgets('captures high resolution images - portrait', (tester) async {
    await tester.runAsync(() async {
      await tester.binding.setSurfaceSize(Size(20, 40));
      final targetResolution = SentryScreenshotQuality.high.targetResolution();
      final fixture = await _Fixture.create(tester,
          width: targetResolution, height: targetResolution);

      expect(await fixture.capture(), '960x1920');
    });
  });

  testWidgets('captures high resolution images - landscape', (tester) async {
    await tester.runAsync(() async {
      await tester.binding.setSurfaceSize(Size(40, 20));
      final targetResolution = SentryScreenshotQuality.high.targetResolution();
      final fixture = await _Fixture.create(tester,
          width: targetResolution, height: targetResolution);

      expect(await fixture.capture(), '1920x960');
    });
  });

  testWidgets('captures medium resolution images', (tester) async {
    await tester.runAsync(() async {
      await tester.binding.setSurfaceSize(Size(20, 40));
      final targetResolution =
          SentryScreenshotQuality.medium.targetResolution();
      final fixture = await _Fixture.create(tester,
          width: targetResolution, height: targetResolution);

      expect(await fixture.capture(), '640x1280');
    });
  });

  testWidgets('captures low resolution images', (tester) async {
    await tester.runAsync(() async {
      await tester.binding.setSurfaceSize(Size(20, 40));
      final targetResolution = SentryScreenshotQuality.low.targetResolution();
      final fixture = await _Fixture.create(tester,
          width: targetResolution, height: targetResolution);

      expect(await fixture.capture(), '427x854');
    });
  });

  testWidgets('propagates errors in test-mode', (tester) async {
    final fixture = await _Fixture.create(tester);
    fixture.options
      ..automatedTestMode = true
      ..privacy.maskCallback<widgets.Stack>((el, widget) {
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
      ..privacy.maskCallback<widgets.Stack>((el, widget) {
        throw Exception('testing masking error');
      });

    expect(await fixture.capture(), isNull);
  });

  group('$Screenshot', () {
    test('listEquals()', () {
      expect(
          Screenshot.listEquals(
            Uint8List(0).buffer.asByteData(),
            Uint8List(0).buffer.asByteData(),
          ),
          isTrue);
      expect(
          Screenshot.listEquals(
            Uint8List.fromList([1, 2, 3]).buffer.asByteData(),
            Uint8List.fromList([1, 2, 3]).buffer.asByteData(),
          ),
          isTrue);
      expect(
          Screenshot.listEquals(
            Uint8List.fromList([1, 0, 3]).buffer.asByteData(),
            Uint8List.fromList([1, 2, 3]).buffer.asByteData(),
          ),
          isFalse);
      expect(
          Screenshot.listEquals(
            Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]).buffer.asByteData(),
            Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]).buffer.asByteData(),
          ),
          isTrue);
      expect(
          Screenshot.listEquals(
            Uint8List.fromList([1, 2, 3, 4, 5, 6, 0, 8]).buffer.asByteData(),
            Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]).buffer.asByteData(),
          ),
          isFalse);
      expect(
          Screenshot.listEquals(
            Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]).buffer.asByteData(),
            Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]).buffer.asByteData(),
          ),
          isTrue);
      expect(
          Screenshot.listEquals(
            Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]).buffer.asByteData(),
            Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 0]).buffer.asByteData(),
          ),
          isFalse);

      final dataA = Uint8List.fromList(
              List.generate(10 * 1000 * 1000, (index) => index % 256))
          .buffer
          .asByteData();
      final dataB = ByteData(dataA.lengthInBytes)
        ..buffer.asUint8List().setAll(0, dataA.buffer.asUint8List());
      expect(Screenshot.listEquals(dataA, dataB), isTrue);

      dataB.setInt8(dataB.lengthInBytes >> 2, 0);
      expect(Screenshot.listEquals(dataA, dataB), isFalse);
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
