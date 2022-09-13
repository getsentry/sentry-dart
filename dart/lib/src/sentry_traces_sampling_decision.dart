import 'package:meta/meta.dart';

/// it should be @internal but its needed when creating SentryTransactionContext
@experimental
class SentryTracesSamplingDecision {
  SentryTracesSamplingDecision(
    this.sampled, {
    this.sampleRate,
  });

  final bool sampled;
  final double? sampleRate;
}
