import 'dart:async';

import 'telemetry_item.dart';

abstract class TelemetryBuffer<T extends TelemetryItem> {
  void add(T item);
  FutureOr<void> flush();
}

/// Holds both raw item and encoded bytes for size tracking and grouping.
class BufferedItem<T extends TelemetryItem> {
  final T item;
  final List<int> encoded;

  BufferedItem(this.item, this.encoded);
}
