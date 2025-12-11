import 'dart:async';

import '../sentry.dart';

abstract class TelemetryPayload {
  Map<String, dynamic> toJson();
}

abstract class TelemetryBuffer<T extends TelemetryPayload> {
  void add(T item);
  FutureOr<void> flush();
}
