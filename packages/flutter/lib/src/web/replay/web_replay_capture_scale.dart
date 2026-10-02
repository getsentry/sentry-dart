import 'package:meta/meta.dart';

import '../../replay/replay_quality.dart';

/// Web's capture-resolution factor for [quality], as a multiplier on the
/// boundary's real (unscaled) window size.
///
/// Independent of [SentryReplayQuality.resolutionScalingFactor]: mobile's
/// tiers are mild (0.8x-1.0x) since its main cost lever is a low capture
/// rate, while web's per-frame Dart-side cost scales with resolution and
/// needs a wider range (see #2897).
@internal
double webReplayCaptureScale(SentryReplayQuality quality) => switch (quality) {
      SentryReplayQuality.low => 0.5,
      SentryReplayQuality.medium => 0.7,
      SentryReplayQuality.high => 1.0,
    };
