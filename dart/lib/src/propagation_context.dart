import 'dart:math';
import 'package:meta/meta.dart';

import '../sentry.dart';

@internal
class PropagationContext {
  PropagationContext();

  /// The trace identifier for the current context.
  SentryId traceId = SentryId.newId();

  /// Random value (0.0 ≤ x < 1.0) used by the SDK for traces sampling.
  double sampleRand = Random().nextDouble();

  /// Indicates whether this trace was sampled.
  bool? sampled;

  /// Dynamic sampling context (a.k.a. Sentry “baggage”).
  SentryBaggage? baggage;

  /// Converts [baggage] to an HTTP `baggage` header.
  SentryBaggageHeader? toBaggageHeader() =>
      baggage != null ? SentryBaggageHeader.fromBaggage(baggage!) : null;

  /// Generates a `sentry-trace` header for outbound requests.
  SentryTraceHeader toSentryTrace() =>
      generateSentryTraceHeader(traceId: traceId, sampled: sampled);
}
