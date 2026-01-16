import 'package:meta/meta.dart';

import '../../../sentry.dart';

/// Base interface for attribute providers used in telemetry enrichment.
///
/// Providers compute attributes that are added to telemetry items (spans, logs).
@internal
abstract interface class TelemetryAttributesProvider {
  /// Extracts attributes for the given [item].
  ///
  /// Returns an empty map when [item] is not a supported/recognized type.
  ///
  /// Contract:
  /// - Must not mutate [item] or [scope].
  /// - Must not perform expensive work.
  /// - Must not include PII values unless [SentryOptions.sendDefaultPii] is enabled.
  Future<Map<String, SentryAttribute>> attributes(
    Object item, {
    Scope? scope,
  });
}
