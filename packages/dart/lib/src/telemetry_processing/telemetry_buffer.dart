import 'dart:async';

import 'sentry_encodable.dart';

abstract class TelemetryBuffer<T extends SentryEncodable> {
  void add(T item);
  FutureOr<void> flush();
}

/// Represents an item that is being hold in a buffer.
///
/// Contains both raw item and encoded bytes for size tracking and grouping.
class BufferedItem<T extends SentryEncodable> {
  final T item;
  final List<int> encoded;

  BufferedItem(this.item, this.encoded);
}

/// In-memory buffer with time and size-based flushing.
class InMemoryTelemetryBuffer<T extends SentryEncodable>
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
