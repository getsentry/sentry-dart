import 'package:meta/meta.dart';

/// The quality of the captured replay.
enum SentryReplayQuality {
  high(resolutionScalingFactor: 1.0, level: 2),
  medium(resolutionScalingFactor: 1.0, level: 1),
  low(resolutionScalingFactor: 0.8, level: 0);

  @internal
  final double resolutionScalingFactor;

  @internal
  final int level;

  const SentryReplayQuality(
      {required this.resolutionScalingFactor, required this.level});
}
