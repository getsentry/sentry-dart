import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';

/// Base interface for attribute providers used in telemetry enrichment.
///
/// Providers compute attributes that are added to telemetry items (spans, logs).
/// Each provider can filter which items it supports via [supports].
@internal
abstract class TelemetryAttributesProvider {
  @protected
  bool supports(Object item);

  @protected
  Future<Map<String, SentryAttribute>> computeAttributes(
    Object item, {
    Scope? scope,
  });

  /// Attributes for the given [item].
  ///
  /// Returns an empty map if [supports] returns `false` for the given [item].
  Future<Map<String, SentryAttribute>> attributes(
    Object item, {
    Scope? scope,
  }) {
    if (!supports(item)) return Future.value({});
    return computeAttributes(item, scope: scope);
  }
}
