import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/screenshot/recorder_config.dart';

void main() async {
  group('$ScreenshotRecorderConfig', () {
    test('defaults', () {
      var sut = ScreenshotRecorderConfig();
      expect(sut.height, isNull);
      expect(sut.width, isNull);
    });
  });

  test('pixel ratio calculation', () {
    expect(ScreenshotRecorderConfig().getPixelRatio(100, 100), null);
    expect(
        ScreenshotRecorderConfig(width: 5, height: 10).getPixelRatio(100, 100),
        0.05);
    expect(
        ScreenshotRecorderConfig(width: 20, height: 10).getPixelRatio(100, 100),
        0.1);
  });
}
