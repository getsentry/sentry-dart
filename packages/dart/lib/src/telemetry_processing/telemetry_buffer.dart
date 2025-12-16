import 'dart:async';

import 'telemetry_item.dart';

abstract class TelemetryBuffer<T extends TelemetryItem> {
  void add(T item);
  FutureOr<void> flush();
}

/// Holds both raw item and encoded bytes for size tracking and grouping.
class EncodedTelemetryItem<T extends TelemetryItem> {
  final T item;
  final List<int> encoded;

  EncodedTelemetryItem(this.item, this.encoded);
}

/// In-memory buffer with time and size-based flushing.
class InMemoryTelemetryBuffer<T extends TelemetryItem>
    extends TelemetryBuffer<T> {
  @override
  void add(T item) {
    // TODO(next-pr)
  }

  @override
  FutureOr<void> flush() {
    // TODO(next-pr)
  }
}
