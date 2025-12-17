import 'dart:async';

import '../../sentry.dart';
import 'envelope_builder.dart';
import 'json_encodable.dart';

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

/// Pairs an item with its encoded bytes for size tracking and transmission.
class BufferedItem<T> {
  final T item;
  final List<int> encoded;

  BufferedItem(this.item, this.encoded);
}

/// In-memory buffer with time and size-based flushing.
class InMemoryTelemetryBuffer<T extends JsonEncodable>
    extends TelemetryBuffer<T> {
  final SdkLogCallback _logger;
  final EnvelopeBuilder<T> _envelopeBuilder;
  final Transport _transport;
  final Duration _flushTimeout;
  final int _maxBufferSizeBytes;

  Timer? _flushTimer;
  final List<BufferedItem<T>> _items = [];
  int _bufferSize = 0;

  InMemoryTelemetryBuffer({
    required SdkLogCallback logger,
    required EnvelopeBuilder<T> envelopeBuilder,
    required Transport transport,
    Duration? flushTimeout,
    int? maxBufferSizeBytes,
  })  : _logger = logger,
        _envelopeBuilder = envelopeBuilder,
        _transport = transport,
        _flushTimeout = flushTimeout ?? const Duration(seconds: 5),
        _maxBufferSizeBytes = maxBufferSizeBytes ??
            1024 * 1024; // 1MB default per Mobile Buffer spec

  @override
  void add(T item) {
    try {
      final encoded = utf8JsonEncoder.convert(item.toJson());
      _items.add(BufferedItem(item, encoded));
      _bufferSize += encoded.length;

      if (_bufferSize >= _maxBufferSizeBytes) {
        _performFlush();
      } else if (_flushTimer == null) {
        _startTimer();
      }
      // Timer is not restarted on subsequent additions per spec
    } catch (error) {
      _logger(
        SentryLevel.error,
        '$InMemoryTelemetryBuffer for $T: Failed to encode item: $error',
      );
    }
  }

  @override
  FutureOr<void> flush() => _performFlush();

  void _startTimer() {
    _flushTimer = Timer(_flushTimeout, () {
      _logger(
        SentryLevel.debug,
        '$InMemoryTelemetryBuffer for $T: Timer fired, flushing.',
      );
      _performFlush();
    });
  }

  FutureOr<void> _performFlush() {
    _flushTimer?.cancel();
    _flushTimer = null;

    final itemsToSend = List<BufferedItem<T>>.from(_items);
    _items.clear();
    _bufferSize = 0;

    if (itemsToSend.isEmpty) {
      _logger(
        SentryLevel.debug,
        '$InMemoryTelemetryBuffer for $T: No data to flush.',
      );
      return null;
    }

    return _buildAndSend(itemsToSend);
  }

  Future<void> _buildAndSend(List<BufferedItem<T>> items) async {
    try {
      final envelopes = _envelopeBuilder.build(items);
      await Future.wait(envelopes.map((envelope) => _transport.send(envelope)));
    } catch (error, stackTrace) {
      _logger(
        SentryLevel.error,
        '$InMemoryTelemetryBuffer for $T: Failed to flush items: $error',
        stackTrace: stackTrace,
      );
    }
  }
}
