import 'package:sentry/src/telemetry_processing/json_encodable.dart';

/// Mock for testing generic telemetry processing.
class MockJsonEncodable implements JsonEncodable {
  final String? id;

  MockJsonEncodable([this.id]);

  @override
  Map<String, dynamic> toJson() =>
      id != null ? {'id': id} : <String, dynamic>{};
}

/// Mock that throws on serialization.
class ThrowingTelemetryItem extends MockJsonEncodable {
  ThrowingTelemetryItem() : super('throwing');

  @override
  Map<String, dynamic> toJson() => throw Exception('Encoding failed');
}
