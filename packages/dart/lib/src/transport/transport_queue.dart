import '../sentry_envelope.dart';
import 'data_category.dart';

/// Represents an envelope with its associated category for queue management.
class QueuedEnvelope {
  final SentryEnvelope envelope;
  final DataCategory category;
  final DateTime enqueuedAt;

  QueuedEnvelope({
    required this.envelope,
    required this.category,
    DateTime? enqueuedAt,
  }) : enqueuedAt = enqueuedAt ?? DateTime.now();
}

/// A queue for managing envelopes before sending to Sentry.
///
/// Different implementations can provide different queuing strategies:
/// - LIFO (Last In, First Out)
/// - Round-robin (fair distribution across categories)
/// - Priority-based
/// - Disk-backed (for offline caching)
///
/// The queue is category-aware to enable fair scheduling and prevent
/// high-volume categories (e.g., logs) from starving low-volume but
/// important categories (e.g., errors).
abstract class TransportQueue {
  /// Adds an envelope to the queue.
  ///
  /// [category] identifies the data type for scheduling purposes.
  /// Returns true if the envelope was queued, false if dropped (e.g., overflow).
  bool enqueue(SentryEnvelope envelope, DataCategory category);

  /// Removes and returns the next envelope to send.
  ///
  /// The selection strategy depends on the implementation (LIFO, round-robin, etc.)
  /// Returns null if the queue is empty.
  QueuedEnvelope? dequeue();

  /// Returns true if there are envelopes waiting to be sent.
  bool get isNotEmpty;

  /// Returns true if the queue has no envelopes.
  bool get isEmpty;

  /// Returns the current number of queued envelopes across all categories.
  int get length;

  /// Clears all envelopes from the queue.
  void clear();
}
