import 'dart:async';

import 'package:sentry/src/telemetry_processing/telemetry_item.dart';
import 'package:sentry/src/telemetry_processing/telemetry_processor.dart';

class MockTelemetryProcessor implements TelemetryProcessor {
  final Future<void> Function()? onFlush;
  final addedItems = <TelemetryItem>[];
  int flushCallCount = 0;

  MockTelemetryProcessor({this.onFlush});

  @override
  void add<T extends TelemetryItem>(T item) {
    addedItems.add(item);
  }

  @override
  FutureOr<void> flush() async {
    flushCallCount++;
    await onFlush?.call();
  }
}
