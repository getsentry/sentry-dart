import 'dart:math';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';

@internal
class ScreenshotRecorderConfig {
  int? srcWidth;
  int? srcHeight;
  final SentryScreenshotQuality quality;

  ScreenshotRecorderConfig({
    this.srcWidth,
    this.srcHeight,
    this.quality = SentryScreenshotQuality.low,
  });

  double getPixelRatio(double targetWidth, double targetHeight) {
    assert((srcWidth == null) == (srcHeight == null));
    if (srcWidth == null || srcHeight == null) {
      return 1.0;
    }
    return min(targetWidth / srcWidth!, targetHeight / srcHeight!);
  }
}
