class SentryTracesSamplingDecision {
  SentryTracesSamplingDecision(
    this.sampled, {
    this.sampleRate,
  });

  final bool sampled;
  final double? sampleRate;
}
