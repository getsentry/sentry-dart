import '../screenshot/recorder_config.dart';

class ScheduledScreenshotRecorderConfig extends ScreenshotRecorderConfig {
  final int frameRate;

  ScheduledScreenshotRecorderConfig({
    super.targetWidth,
    super.targetHeight,
    required this.frameRate,
  });
}
