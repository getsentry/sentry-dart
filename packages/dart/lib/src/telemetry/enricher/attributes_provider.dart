import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';

/// Computes attributes for telemetry enrichment.
///
/// Providers are the source of attributes - they compute values from
/// scope, options, or other context. Providers are registered with
/// the pipeline and automatically used by aggregators.
@internal
abstract class TelemetryAttributesProvider {
  /// Computes attributes to be added to telemetry.
  ///
  /// Return a [Future] only if async work is required.
  FutureOr<Map<String, SentryAttribute>> provide();
}
