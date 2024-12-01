import 'package:meta/meta.dart';

import 'scheduled_recorder_config.dart';

@immutable
@internal
class ReplayConfig extends ScheduledScreenshotRecorderConfig {
  @override
  int get width => super.width!;

  @override
  int get height => super.height!;

  final int bitRate;

  ReplayConfig({
    required int super.width,
    required int super.height,
    required super.frameRate,
    required this.bitRate,
  });
}
