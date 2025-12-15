import 'dart:async';

import 'telemetry_item.dart';

/// Abstract buffer interface for telemetry items.
abstract class TelemetryBuffer<T extends TelemetryItem> {
  void add(T item);
  FutureOr<void> flush();
}

/// A buffered item containing both the raw item and its encoded bytes.
/// This allows accurate size tracking while preserving access to raw data
/// for grouping/inspection by envelope builders.
class BufferedItem<T extends TelemetryItem> {
  final T item;
  final List<int> encoded;

  BufferedItem(this.item, this.encoded);
}
