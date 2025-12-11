import 'dart:async';

import '../sentry.dart';

abstract class TelemetryPayload {
  Map<String, dynamic> toJson();
}

abstract class TelemetryBuffer<T extends Telemetry> {
  void add(T item);
  FutureOr<void> flush();
}
