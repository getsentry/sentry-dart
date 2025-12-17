import 'dart:async';

import '../../sentry.dart';
import 'json_encodable.dart';

/// A buffer that batches telemetry items for efficient transmission to Sentry.
///
/// Collects items of type [T] and sends them in batches rather than
/// individually, reducing network overhead.
abstract class TelemetryBuffer<T> {
  /// Adds an item to the buffer.
  void add(T item);

  /// When executed immediately sends all buffered items to Sentry and clears the buffer.
  FutureOr<void> clear();
}

/// Pairs an item with its encoded bytes for size tracking and transmission.
class BufferedItem<T> {
  final T item;
  final List<int> encoded;

  BufferedItem(this.item, this.encoded);
}

/// In-memory buffer with time and size-based flushing.
class InMemoryTelemetryBuffer<T extends JsonEncodable>
    extends TelemetryBuffer<T> {
  InMemoryTelemetryBuffer();

  @override
  void add(T item) {
    final encoded = utf8JsonEncoder.convert(item.toJson());
    final _ = BufferedItem(item, encoded);
    // TODO(next-pr): finish this impl
  }

  @override
  FutureOr<void> clear() {
    // TODO(next-pr): finish this impl
  }
}
