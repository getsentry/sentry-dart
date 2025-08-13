import 'package:meta/meta.dart';

/// The quality of the captured replay.
enum SentryReplayQuality {
  high(resolutionScalingFactor: 1.0),
  medium(resolutionScalingFactor: 1.0),
  low(resolutionScalingFactor: 0.8);

  @internal
  final double resolutionScalingFactor;

  const SentryReplayQuality({required this.resolutionScalingFactor});
}
