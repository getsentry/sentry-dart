import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  group('$SentryScreenshotQuality', () {
    test('test quality: full', () {
      final sut = SentryScreenshotQuality.full;
      expect(sut.targetResolution(), isNull);
      expect(sut.calculateHeight(2000, 4000), 4000);
      expect(sut.calculateWidth(2000, 4000), 2000);
      expect(sut.calculateHeight(4000, 2000), 2000);
      expect(sut.calculateWidth(4000, 2000), 4000);
    });

    test('test quality: high', () {
      final sut = SentryScreenshotQuality.high;
      final res = sut.targetResolution()!;
      expect(res, 1920);
      expect(sut.calculateHeight(2000, 4000), res);
      expect(sut.calculateWidth(2000, 4000), res / 2);
      expect(sut.calculateHeight(4000, 2000), res / 2);
      expect(sut.calculateWidth(4000, 2000), res);
    });

    test('test quality: medium', () {
      final sut = SentryScreenshotQuality.medium;
      final res = sut.targetResolution()!;
      expect(res, 1280);
      expect(sut.calculateHeight(2000, 4000), res);
      expect(sut.calculateWidth(2000, 4000), res / 2);
      expect(sut.calculateHeight(4000, 2000), res / 2);
      expect(sut.calculateWidth(4000, 2000), res);
    });

    test('test quality: low', () {
      final sut = SentryScreenshotQuality.low;
      final res = sut.targetResolution()!;
      expect(res, 854);
      expect(sut.calculateHeight(2000, 4000), res);
      expect(sut.calculateWidth(2000, 4000), res / 2);
      expect(sut.calculateHeight(4000, 2000), res / 2);
      expect(sut.calculateWidth(4000, 2000), res);
    });
  });
}
