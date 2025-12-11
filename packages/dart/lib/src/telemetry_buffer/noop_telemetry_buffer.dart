import 'dart:async';

import 'telemetry_buffer.dart';

class NoOpTelemetryBuffer<T extends TelemetryPayload>
    extends TelemetryBuffer<T> {
  @override
  void add(T item) {}

  @override
  FutureOr<void> flush() {}
}
