import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// ignore_for_file: deprecated_member_use

void main() async {
  group('$SentryScreenshotQuality', () {
    test('test quality: full', () {
      final sut = SentryScreenshotQuality.full;
      expect(sut.targetResolution(), isNull);
    });

    test('test quality: high', () {
      final sut = SentryScreenshotQuality.high;
      final res = sut.targetResolution()!;
      expect(res, 1920);
    });

    test('test quality: medium', () {
      final sut = SentryScreenshotQuality.medium;
      final res = sut.targetResolution()!;
      expect(res, 1280);
    });

    test('test quality: low', () {
      final sut = SentryScreenshotQuality.low;
      final res = sut.targetResolution()!;
      expect(res, 854);
    });
  });
}
