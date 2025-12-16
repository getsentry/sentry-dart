import 'package:sentry/src/telemetry_processing/telemetry_item.dart';

/// Mock telemetry item for testing generic telemetry processing.
class MockTelemetryItem extends TelemetryItem {
  final String? id;

  MockTelemetryItem([this.id]);

  @override
  TelemetryType get type => TelemetryType.unknown;

  @override
  Map<String, dynamic> toJson() =>
      id != null ? {'id': id} : <String, dynamic>{};
}

/// Mock telemetry item that throws on serialization.
class ThrowingTelemetryItem extends MockTelemetryItem {
  ThrowingTelemetryItem() : super('throwing');

  @override
  Map<String, dynamic> toJson() => throw Exception('Encoding failed');
}

