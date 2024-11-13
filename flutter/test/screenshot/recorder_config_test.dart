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
}
