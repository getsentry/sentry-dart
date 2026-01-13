import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';

/// Provider for user-set attributes from [Scope].
///
/// Returns attributes that were explicitly set by the user via
/// [Scope.setAttribute].
///
/// This provider should typically be registered last so user attributes
/// take highest priority in the enrichment pipeline.
@internal
class ScopeTelemetryAttributesProvider implements TelemetryAttributesProvider {
  final Scope _scope;

  ScopeTelemetryAttributesProvider(this._scope);

  @override
  FutureOr<Map<String, SentryAttribute>> attributes(_) => _scope.attributes;
}
