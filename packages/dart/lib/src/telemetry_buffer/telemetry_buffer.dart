import 'dart:async';

/// Represents a telemetry item that can be serialized to JSON.
abstract class TelemetryPayload {
  Map<String, dynamic> toJson();
}

/// Abstract buffer interface for telemetry items.
abstract class TelemetryBuffer<T extends TelemetryPayload> {
  void add(T item);
  FutureOr<void> flush();
}
