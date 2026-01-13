import 'dart:async';

import '../../../sentry.dart';
import 'attributes_provider.dart';

class ScopeTelemetryAttributesProvider implements TelemetryAttributesProvider {
  final Scope _scope;

  ScopeTelemetryAttributesProvider(this._scope);

  @override
  FutureOr<Map<String, SentryAttribute>> attributes() => _scope.attributes;
}
