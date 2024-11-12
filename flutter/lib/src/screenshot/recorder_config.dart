import 'dart:math';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';

@internal
class ScreenshotRecorderConfig {
  int? targetWidth;
  int? targetHeight;
  final SentryScreenshotQuality quality;

  ScreenshotRecorderConfig({
    this.targetWidth,
    this.targetHeight,
    this.quality = SentryScreenshotQuality.low,
  });

  double getPixelRatio(double srcWidth, double srcHeight) {
    assert((targetWidth == null) == (targetHeight == null));
    if (targetWidth == null || targetHeight == null) {
      return 1.0;
    }
    return min(targetWidth! / srcWidth, targetHeight! / srcHeight);
  }
}
