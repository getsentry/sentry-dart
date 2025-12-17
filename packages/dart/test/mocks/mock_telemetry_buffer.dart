import 'dart:async';

import 'package:sentry/src/telemetry_processing/sentry_encodable.dart';
import 'package:sentry/src/telemetry_processing/telemetry_buffer.dart';

class MockTelemetryBuffer<T extends SentryEncodable>
    extends TelemetryBuffer<T> {
  final List<T> addedItems = [];
  int flushCallCount = 0;
  final bool asyncFlush;

  MockTelemetryBuffer({this.asyncFlush = false});

  @override
  void add(T item) => addedItems.add(item);

  @override
  FutureOr<void> flush() {
    flushCallCount++;
    if (asyncFlush) {
      return Future.value();
    }
    return null;
  }
}
