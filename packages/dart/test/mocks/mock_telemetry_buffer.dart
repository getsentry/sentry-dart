import 'dart:async';

import 'package:sentry/src/telemetry_processing/telemetry_buffer.dart';

class MockTelemetryBuffer<T> extends TelemetryBuffer<T> {
  final List<T> addedItems = [];
  int clearCallCount = 0;
  final bool asyncFlush;

  MockTelemetryBuffer({this.asyncFlush = false});

  @override
  void add(T item) => addedItems.add(item);

  @override
  FutureOr<void> clear() {
    clearCallCount++;
    if (asyncFlush) {
      return Future.value();
    }
    return null;
  }
}
