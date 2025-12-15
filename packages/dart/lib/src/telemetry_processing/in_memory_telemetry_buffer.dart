import 'dart:async';

import '../../sentry.dart';
import 'envelope_builder.dart';
import 'telemetry_buffer.dart';
import 'telemetry_item.dart';

/// In-memory buffer for telemetry items with time and size-based flushing.
///
/// This buffer is generic and delegates envelope building to an [EnvelopeBuilder].
/// Dispatch is handled directly using the injected [TransportDispatcher].
class InMemoryTelemetryBuffer<T extends TelemetryItem>
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

  /// Adds a telemetry item to the buffer.
  @override
  void add(T item) {
    try {
      final encoded = utf8JsonEncoder.convert(item.toJson());
      _items.add(BufferedItem(item, encoded));
      _bufferSize += encoded.length;

      // Flush if size threshold is reached
      if (_bufferSize >= _maxBufferSizeBytes) {
        _performFlush();
      } else if (_flushTimer == null) {
        // Start timeout only when first item is added
        _startTimer();
      }
      // Note: We don't restart the timer on subsequent additions per spec
    } catch (error) {
      _logger(
        SentryLevel.error,
        '$InMemoryTelemetryBuffer for $T: Failed to encode item: $error',
      );
    }
  }

  /// Flushes the buffer immediately, sending all buffered telemetry.
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
    // Reset timer state first
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

  /// Builds envelopes and sends them. Async to properly catch all errors.
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
