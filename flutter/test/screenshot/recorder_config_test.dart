import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/screenshot/recorder_config.dart';

void main() async {
  group('$ScreenshotRecorderConfig', () {
    test('defaults', () {
      var sut = ScreenshotRecorderConfig();
      expect(sut.targetHeight, isNull);
      expect(sut.targetWidth, isNull);
    });

    test('pixel ratio calculation', () {
      expect(ScreenshotRecorderConfig().getPixelRatio(100, 100), 1.0);
      expect(
          ScreenshotRecorderConfig(targetWidth: 5, targetHeight: 10)
              .getPixelRatio(100, 100),
          0.05);
      expect(
          ScreenshotRecorderConfig(targetWidth: 20, targetHeight: 10)
              .getPixelRatio(100, 100),
          0.1);
    });
  });
}
