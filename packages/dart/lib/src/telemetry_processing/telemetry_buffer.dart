import 'dart:async';

/// A buffer that batches telemetry items for efficient transmission to Sentry.
///
/// Collects items of type [T] and sends them in batches rather than
/// individually, reducing network overhead.
abstract class TelemetryBuffer<T> {
  /// Adds an item to the buffer.
  void add(T item);

  /// Manually sends all buffered items to Sentry and clears the buffer.
  FutureOr<void> flush();
}

/// Represents an item that is being hold in a buffer.
///
/// Contains both raw item and encoded bytes for size tracking and grouping.
class BufferedItem<T> {
  final T item;
  final List<int> encoded;

  BufferedItem(this.item, this.encoded);
}

/// In-memory buffer with time and size-based flushing.
class InMemoryTelemetryBuffer<T> extends TelemetryBuffer<T> {
  final Map<String, dynamic> Function(T) serializer;

  InMemoryTelemetryBuffer({required this.serializer});

  @override
  void add(T item) {
    final serializedItem = serializer(item);
    // TODO(next-pr)
  }

  @override
  FutureOr<void> flush() {
    // TODO(next-pr)
  }
}
