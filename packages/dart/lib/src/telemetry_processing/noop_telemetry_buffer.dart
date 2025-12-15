import 'dart:async';

import 'telemetry_buffer.dart';
import 'telemetry_item.dart';

class NoOpTelemetryBuffer<T extends TelemetryItem> extends TelemetryBuffer<T> {
  @override
  void add(T item) {}

  @override
  FutureOr<void> flush() {}
}
