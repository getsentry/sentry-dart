import 'package:meta/meta.dart';

import 'scheduled_recorder_config.dart';

@immutable
@internal
class ReplayConfig extends ScheduledScreenshotRecorderConfig {
  @override
  double get width => super.width!;

  @override
  double get height => super.height!;

  const ReplayConfig({
    required double super.width,
    required double super.height,
    super.frameRate = 1,
  });
}
