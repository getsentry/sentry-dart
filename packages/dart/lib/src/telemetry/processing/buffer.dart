import 'dart:async';

/// A buffer that batches telemetry items for efficient transmission to Sentry.
///
/// Collects items of type [T] and sends them in batches rather than
/// individually, reducing network overhead.
abstract class TelemetryBuffer<T> {
  /// Adds an item to the buffer.
  void add(T item);

  /// When executed immediately sends all buffered items to Sentry and clears the buffer.
  FutureOr<void> flush();
}
