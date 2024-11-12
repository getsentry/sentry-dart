import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/screenshot/recorder_config.dart';

void main() async {
  group('$ScreenshotRecorderConfig', () {
    test('defaults', () {
      var sut = ScreenshotRecorderConfig();
      expect(sut.srcHeight, isNull);
      expect(sut.srcWidth, isNull);
    });

    test('pixel ratio calculation', () {
      expect(ScreenshotRecorderConfig().getPixelRatio(100, 100), 1.0);
      expect(
          ScreenshotRecorderConfig(srcWidth: 5, srcHeight: 10)
              .getPixelRatio(100, 100),
          0.05);
      expect(
          ScreenshotRecorderConfig(srcWidth: 20, srcHeight: 10)
              .getPixelRatio(100, 100),
          0.1);
    });
  });
}
