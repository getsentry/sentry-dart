import 'package:meta/meta.dart';

@internal
class ScreenshotRecorderConfig {
  final int width;
  final int height;
  final int frameRate;

  ScreenshotRecorderConfig(this.width, this.height, this.frameRate);
}
