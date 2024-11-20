import 'dart:math';

import 'package:meta/meta.dart';

@internal
class ScreenshotRecorderConfig {
  final int? width;
  final int? height;

  const ScreenshotRecorderConfig({this.width, this.height});

  double getPixelRatio(double srcWidth, double srcHeight) {
    assert((width == null) == (height == null));
    if (width == null || height == null) {
      return 1.0;
    }
    return min(width! / srcWidth, height! / srcHeight);
  }
}

class ScheduledScreenshotRecorderConfig extends ScreenshotRecorderConfig {
  final int frameRate;

  const ScheduledScreenshotRecorderConfig({
    super.width,
    super.height,
    required this.frameRate,
  });
}
