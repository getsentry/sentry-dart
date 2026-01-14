import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';

/// Base interface for attribute providers used in telemetry enrichment.
///
/// Providers compute attributes that are added to telemetry items (spans, logs).
/// Each provider can filter which items it supports via [supports].
@internal
abstract interface class TelemetryAttributesProvider {
  /// Returns true if this provider should contribute attributes for [item].
  bool supports(Object item);

  /// Computes attributes for the given [item].
  ///
  /// Return a [Future] only if async work is required.
  FutureOr<Map<String, SentryAttribute>> attributes(Object item,
      {Scope? scope});
}
