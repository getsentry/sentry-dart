import 'dart:ui';

/// Distance between the engine's monotonic epoch and [DateTime]'s in the
/// timings below.
///
/// Real `FrameTiming` phases are not epoch microseconds — only
/// `rasterFinishWallTime` is — so a fake that used wall values throughout
/// would let code that conflates the two pass. Skewing them keeps the fake
/// honest. It is added rather than subtracted so a fixture whose process
/// starts at the epoch still gets positive phases.
const _monotonicEpochSkew = 1600000000000000;

/// Builds a [FrameTiming] whose phases resolve to the given wall-clock
/// instants.
FrameTiming fakeFirstFrameTiming({
  required DateTime vsyncStart,
  required DateTime buildStart,
  required DateTime buildFinish,
  required DateTime rasterStart,
  required DateTime rasterFinish,
}) {
  int monotonic(DateTime timestamp) =>
      timestamp.microsecondsSinceEpoch + _monotonicEpochSkew;

  return FrameTiming(
    vsyncStart: monotonic(vsyncStart),
    buildStart: monotonic(buildStart),
    buildFinish: monotonic(buildFinish),
    rasterStart: monotonic(rasterStart),
    rasterFinish: monotonic(rasterFinish),
    rasterFinishWallTime: rasterFinish.microsecondsSinceEpoch,
  );
}
