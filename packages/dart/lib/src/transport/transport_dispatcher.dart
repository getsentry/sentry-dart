import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry.dart';
import 'data_category.dart';
import 'round_robin_transport_queue.dart';
import 'transport.dart';
import 'transport_queue.dart';

/// The TransportDispatcher manages the flow of envelopes from buffers to Sentry.
///
/// Key responsibilities:
/// - Accepts envelopes from buffers and enqueues them
/// - Uses a [TransportQueue] for fair scheduling (round-robin, LIFO, etc.)
/// - Processes the queue asynchronously
/// - Can be configured with different queue strategies
///
/// ## Usage
///
/// ```dart
/// final dispatcher = TransportDispatcher(
///   options: options,
///   transport: httpTransport,
///   queue: RoundRobinTransportQueue(options: options),
/// );
///
/// // Buffers call this when they flush:
/// dispatcher.enqueue(envelope, DataCategory.log);
///
/// // Process queued envelopes (call periodically or on flush)
/// await dispatcher.processQueue();
/// ```
@internal
class TransportDispatcher {
  final SentryOptions _options;
  final Transport _transport;
  final TransportQueue _queue;

  /// Whether the dispatcher is currently processing the queue.
  bool _isProcessing = false;

  /// Creates a dispatcher with the given transport and queue strategy.
  ///
  /// Defaults to [RoundRobinTransportQueue] for fair scheduling.
  TransportDispatcher({
    required SentryOptions options,
    required Transport transport,
    TransportQueue? queue,
  })  : _options = options,
        _transport = transport,
        _queue = queue ?? RoundRobinTransportQueue(options: options);

  /// The underlying queue (exposed for testing/debugging).
  TransportQueue get queue => _queue;

  /// Enqueues an envelope for sending.
  ///
  /// Returns true if the envelope was queued, false if dropped (e.g., overflow).
  /// The actual sending happens when [processQueue] or [processNext] is called.
  bool enqueue(SentryEnvelope envelope, DataCategory category) {
    final success = _queue.enqueue(envelope, category);

    if (success) {
      _options.log(
        SentryLevel.debug,
        'TransportDispatcher: Enqueued ${category.name} envelope, queue size: ${_queue.length}',
      );
    }

    return success;
  }

  /// Enqueues an envelope and immediately triggers queue processing.
  ///
  /// This is a convenience method that combines [enqueue] and [processQueue].
  /// Use this when you want fire-and-forget sending behavior.
  Future<void> enqueueAndProcess(
    SentryEnvelope envelope,
    DataCategory category,
  ) async {
    enqueue(envelope, category);
    await processQueue();
  }

  /// Processes all envelopes in the queue, sending them via the transport.
  ///
  /// Uses the queue's scheduling strategy (round-robin, LIFO, etc.) to
  /// determine the order of sending.
  ///
  /// This method is safe to call concurrently - only one processing loop
  /// will run at a time.
  Future<void> processQueue() async {
    if (_isProcessing) {
      _options.log(
        SentryLevel.debug,
        'TransportDispatcher: Already processing queue, skipping.',
      );
      return;
    }

    _isProcessing = true;
    try {
      while (_queue.isNotEmpty) {
        await processNext();
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Processes the next envelope in the queue.
  ///
  /// Returns true if an envelope was processed, false if the queue was empty.
  Future<bool> processNext() async {
    final queued = _queue.dequeue();
    if (queued == null) return false;

    try {
      _options.log(
        SentryLevel.debug,
        'TransportDispatcher: Sending ${queued.category.name} envelope.',
      );

      await _transport.send(queued.envelope);

      _options.log(
        SentryLevel.debug,
        'TransportDispatcher: Sent ${queued.category.name} envelope successfully.',
      );
    } catch (error) {
      _options.log(
        SentryLevel.error,
        'TransportDispatcher: Failed to send ${queued.category.name} envelope: $error',
      );
      // TODO: Handle retry logic, rate limiting, client reports
    }

    return true;
  }

  /// Returns true if there are envelopes waiting to be sent.
  bool get hasPendingEnvelopes => _queue.isNotEmpty;

  /// Returns the number of envelopes waiting to be sent.
  int get pendingCount => _queue.length;

  /// Clears all pending envelopes from the queue.
  void clear() {
    _queue.clear();
    _options.log(
      SentryLevel.debug,
      'TransportDispatcher: Queue cleared.',
    );
  }
}
