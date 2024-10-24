import 'dart:math';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';

@internal
class ScreenshotRecorderConfig {
  final int? width;
  final int? height;
  final SentryScreenshotQuality quality;

  const ScreenshotRecorderConfig({
    this.width,
    this.height,
    this.quality = SentryScreenshotQuality.full,
  });

  double getPixelRatio(double srcWidth, double srcHeight) {
    assert((width == null) == (height == null));
    if (width == null || height == null) {
      return 1.0;
    }
    return min(width! / srcWidth, height! / srcHeight);
  }
}
