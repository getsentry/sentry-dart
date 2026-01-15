import 'package:meta/meta.dart';

import '../../../sentry.dart';

/// Base interface for attribute providers used in telemetry enrichment.
///
/// Providers compute attributes that are added to telemetry items (spans, logs).
@internal
abstract interface class TelemetryAttributesProvider {
  /// Attributes for the given [item].
  ///
  /// Returns an empty map if [item] is not supported.
  Future<Map<String, SentryAttribute>> attributes(
    Object item, {
    Scope? scope,
  });
}
