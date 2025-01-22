import 'dart:math';

import 'package:meta/meta.dart';

@internal
class ScreenshotRecorderConfig {
  final double? width;
  final double? height;
  final double? pixelRatio;

  const ScreenshotRecorderConfig({this.width, this.height, this.pixelRatio});

  double? getPixelRatio(double srcWidth, double srcHeight) {
    assert((width == null) == (height == null),
        "Screenshot width and height must be both set or both null (automatic).");
    assert(pixelRatio == null || (pixelRatio! > 0 && pixelRatio! <= 1.0),
        'Screenshot pixelRatio must be between 0 and 1.');
    assert(!(width != null && pixelRatio != null),
        'Screenshot config may only define the size (width & height) or the pixelRatio, not both.');

    if (pixelRatio != null) {
      return pixelRatio;
    } else if (width != null && height != null) {
      return min(width! / srcWidth, height! / srcHeight);
    } else {
      return null;
    }
  }
}
