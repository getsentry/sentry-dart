import 'dart:collection';

import '../../sentry.dart';
import 'transport_queue.dart';
import 'data_category.dart';

/// A transport queue that uses round-robin scheduling across categories
/// to prevent starvation of any single category.
///
/// When multiple categories have envelopes queued, this implementation
/// cycles through them fairly, ensuring that high-volume categories
/// (like logs or spans) don't starve low-volume but important categories
/// (like errors or check-ins).
///
/// Example behavior with 3 categories:
/// ```
/// Queue state: logs=[L1,L2,L3], spans=[S1], errors=[E1,E2]
///
/// dequeue() -> E1  (errors turn)
/// dequeue() -> L1  (logs turn)
/// dequeue() -> S1  (spans turn)
/// dequeue() -> E2  (errors turn)
/// dequeue() -> L2  (logs turn - spans queue empty, skip)
/// dequeue() -> L3  (logs turn - only logs left)
/// ```
class RoundRobinTransportQueue implements TransportQueue {
  final int _maxQueueSize;
  final SentryOptions _options;

  /// Per-category queues for fair scheduling.
  final Map<DataCategory, Queue<QueuedEnvelope>> _categoryQueues = {};

  /// Ordered list of categories that have been seen, for round-robin iteration.
  final List<DataCategory> _categoryOrder = [];

  /// Current position in the round-robin rotation.
  int _currentIndex = 0;

  /// Total count of all envelopes across categories.
  int _totalCount = 0;

  /// Creates a round-robin queue with the specified maximum size.
  ///
  /// When the queue reaches [maxQueueSize], new envelopes will be dropped.
  RoundRobinTransportQueue({
    required SentryOptions options,
    int maxQueueSize = 30,
  })  : _options = options,
        _maxQueueSize = maxQueueSize;

  @override
  bool enqueue(SentryEnvelope envelope, DataCategory category) {
    if (_totalCount >= _maxQueueSize) {
      _options.log(
        SentryLevel.warning,
        'RoundRobinTransportQueue: Queue full ($_maxQueueSize), dropping envelope.',
      );
      // TODO: Record client report for dropped envelope
      return false;
    }

    // Get or create queue for this category
    if (!_categoryQueues.containsKey(category)) {
      _categoryQueues[category] = Queue<QueuedEnvelope>();
      _categoryOrder.add(category);
    }

    _categoryQueues[category]!.add(QueuedEnvelope(
      envelope: envelope,
      category: category,
    ));
    _totalCount++;

    _options.log(
      SentryLevel.debug,
      'RoundRobinTransportQueue: Enqueued ${category.name}, total: $_totalCount',
    );

    return true;
  }

  @override
  QueuedEnvelope? dequeue() {
    if (_totalCount == 0) return null;

    // Find next non-empty category using round-robin
    final startIndex = _currentIndex;
    do {
      if (_categoryOrder.isEmpty) return null;

      final category = _categoryOrder[_currentIndex % _categoryOrder.length];
      final queue = _categoryQueues[category];

      // Move to next category for next dequeue
      _currentIndex = (_currentIndex + 1) % _categoryOrder.length;

      if (queue != null && queue.isNotEmpty) {
        final envelope = queue.removeFirst();
        _totalCount--;

        // Clean up empty queues
        if (queue.isEmpty) {
          _categoryQueues.remove(category);
          _categoryOrder.remove(category);
          // Adjust index if we removed a category before current position
          if (_currentIndex > 0) {
            _currentIndex = _currentIndex %
                (_categoryOrder.isEmpty ? 1 : _categoryOrder.length);
          }
        }

        _options.log(
          SentryLevel.debug,
          'RoundRobinTransportQueue: Dequeued ${category.name}, remaining: $_totalCount',
        );

        return envelope;
      }
    } while (_currentIndex != startIndex && _categoryOrder.isNotEmpty);

    return null;
  }

  @override
  bool get isNotEmpty => _totalCount > 0;

  @override
  bool get isEmpty => _totalCount == 0;

  @override
  int get length => _totalCount;

  @override
  void clear() {
    _categoryQueues.clear();
    _categoryOrder.clear();
    _totalCount = 0;
    _currentIndex = 0;
  }

  /// Returns the number of envelopes queued for a specific category.
  int countForCategory(DataCategory category) {
    return _categoryQueues[category]?.length ?? 0;
  }

  /// Returns all categories that currently have queued envelopes.
  List<DataCategory> get activeCategories => List.unmodifiable(_categoryOrder);
}
