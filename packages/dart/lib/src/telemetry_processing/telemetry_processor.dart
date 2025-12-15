import 'dart:async';

import 'telemetry_item.dart';

/// Manages buffering and sending of telemetry data to Sentry.
abstract class TelemetryProcessor {
  void add(TelemetryItem item);
  FutureOr<void> flush();
}
