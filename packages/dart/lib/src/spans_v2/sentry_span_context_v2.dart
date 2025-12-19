import 'package:meta/meta.dart';

import '../../sentry.dart';
import '../telemetry_processing/envelope_builder.dart';

/// Context for creating and managing spans.
///
/// This object bundles the dependencies that spans need from their
/// environment, avoiding direct coupling to the Hub.
@immutable
class SentrySpanContextV2 {
  /// Debug logger.
  final SdkLogCallback? log;

  /// Datetime factory.
  final ClockProvider clock;

  /// The default trace id.
  final SentryId traceId;

  /// Callback that triggers when [RecordingSentrySpanV2.end] is executed.
  final SpanEndedCallback onSpanEnded;

  /// Factory for creating the dynamic sampling context.
  final TraceContextHeaderFactory createDsc;

  SentrySpanContextV2({
    required this.log,
    required this.clock,
    required this.traceId,
    required this.onSpanEnded,
    required this.createDsc,
  });
}
