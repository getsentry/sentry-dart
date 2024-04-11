import 'package:meta/meta.dart';

@internal
class ScreenshotRecorderConfig {
  final int width;
  final int height;
  final int frameRate;
  final int bitRate;

  ScreenshotRecorderConfig(this.width, this.height, this.frameRate, this.bitRate)
}
