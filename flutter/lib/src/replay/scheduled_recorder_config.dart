import '../screenshot/recorder_config.dart';

class ScheduledScreenshotRecorderConfig extends ScreenshotRecorderConfig {
  final int frameRate;

  ScheduledScreenshotRecorderConfig({
    super.width,
    super.height,
    required this.frameRate,
  });
}
