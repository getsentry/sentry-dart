import '../sentry_envelope.dart';
import 'data_category.dart';
import 'transport_queue.dart';

/// A no-op transport queue that doesn't actually queue anything.
///
/// This is useful for:
/// - Testing scenarios where you don't want queuing behavior
/// - Backwards compatibility when queue functionality isn't needed
/// - Platforms where immediate sending is preferred
///
/// All envelopes are immediately "dequeued" after being "enqueued",
/// meaning they bypass any buffering or scheduling logic.
class NoOpTransportQueue implements TransportQueue {
  QueuedEnvelope? _pending;

  @override
  bool enqueue(SentryEnvelope envelope, DataCategory category) {
    _pending = QueuedEnvelope(envelope: envelope, category: category);
    return true;
  }

  @override
  QueuedEnvelope? dequeue() {
    final result = _pending;
    _pending = null;
    return result;
  }

  @override
  bool get isNotEmpty => _pending != null;

  @override
  bool get isEmpty => _pending == null;

  @override
  int get length => _pending != null ? 1 : 0;

  @override
  void clear() {
    _pending = null;
  }
}
