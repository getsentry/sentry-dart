import 'dart:async';

import 'telemetry_item.dart';
import 'telemetry_processor.dart';

class NoOpTelemetryProcessor implements TelemetryProcessor {
  @override
  void add(TelemetryItem item) {}

  @override
  FutureOr<void> flush() {}
}
