import 'package:meta/meta.dart';

@internal
class ScreenshotRecorderConfig {
  final int width;
  final int height;
  final int frameRate;

  ScreenshotRecorderConfig(
      {required this.width, required this.height, required this.frameRate});
}
