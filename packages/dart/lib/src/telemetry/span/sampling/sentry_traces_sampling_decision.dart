class SentryTracesSamplingDecision {
  SentryTracesSamplingDecision(
    this.sampled, {
    this.sampleRate,
    this.sampleRand,
  });

  final bool sampled;
  final double? sampleRate;
  final double? sampleRand;
}
