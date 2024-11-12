import '../screenshot/recorder_config.dart';

class ScheduledScreenshotRecorderConfig extends ScreenshotRecorderConfig {
  final int frameRate;

  ScheduledScreenshotRecorderConfig({
    super.srcWidth,
    super.srcHeight,
    required this.frameRate,
  });
}
