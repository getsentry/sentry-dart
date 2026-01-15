import 'package:sentry/sentry.dart';

class MockTelemetryAttributesProvider implements TelemetryAttributesProvider {
  final Map<String, String> _attributes;
  int callCount = 0;

  MockTelemetryAttributesProvider(this._attributes);

  @override
  Future<Map<String, SentryAttribute>> attributes(Object item,
      {Scope? scope}) async {
    callCount++;
    return _attributes.map((k, v) => MapEntry(k, SentryAttribute.string(v)));
  }
}
