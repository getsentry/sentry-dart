import 'dart:async';

import '../../sentry.dart';
import 'buffer_flusher.dart';
import 'telemetry_buffer.dart';

/// In-memory buffer for telemetry items with time and size-based flushing.
///
/// This buffer is generic and delegates all domain-specific logic
/// (grouping, envelope creation, sending) to a [BufferFlusher].
class InMemoryTelemetryBuffer<T extends TelemetryPayload>
    extends TelemetryBuffer<T> {
  final SentryOptions _options;
  final BufferFlusher<T> _flusher;
  final Duration _flushTimeout;
  final int _maxBufferSizeBytes;

  Timer? _flushTimer;
  final List<BufferedItem<T>> _items = [];
  int _bufferSize = 0;

  InMemoryTelemetryBuffer._(
    this._options,
    this._flusher, {
    Duration? flushTimeout,
    int? maxBufferSizeBytes,
  })  : _flushTimeout = flushTimeout ?? const Duration(seconds: 5),
        _maxBufferSizeBytes = maxBufferSizeBytes ??
            1024 * 1024; // 1MB default per Mobile Buffer spec

  /// Creates a buffer for logs.
  ///
  /// Optionally provide a custom [flusher] for testing.
  static InMemoryTelemetryBuffer<SentryLog> forLogs(
    SentryOptions options, {
    BufferFlusher<SentryLog>? flusher,
    Duration? flushTimeout,
    int? maxBufferSizeBytes,
  }) =>
      InMemoryTelemetryBuffer._(
        options,
        flusher ?? LogBufferFlusher(options),
        flushTimeout: flushTimeout,
        maxBufferSizeBytes: maxBufferSizeBytes,
      );

  /// Creates a buffer for spans.
  ///
  /// Optionally provide a custom [flusher] for testing.
  static InMemoryTelemetryBuffer<Span> forSpans(
    SentryOptions options, {
    BufferFlusher<Span>? flusher,
    Duration? flushTimeout,
    int? maxBufferSizeBytes,
  }) =>
      InMemoryTelemetryBuffer._(
        options,
        flusher ?? SpanBufferFlusher(options),
        flushTimeout: flushTimeout,
        maxBufferSizeBytes: maxBufferSizeBytes,
      );

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
      _options.log(
        SentryLevel.error,
        '$InMemoryTelemetryBuffer<$T>: Failed to encode item: $error',
      );
    }
  }

  /// Flushes the buffer immediately, sending all buffered telemetry.
  @override
  FutureOr<void> flush() => _performFlush();

  void _startTimer() {
    _flushTimer = Timer(_flushTimeout, () {
      _options.log(
        SentryLevel.debug,
        '$InMemoryTelemetryBuffer<$T>: Timer fired, flushing.',
      );
      _performFlush();
    });
  }

  FutureOr<void> _performFlush() {
    // Reset timer state first
    _flushTimer?.cancel();
    _flushTimer = null;

    // Capture and clear buffer
    final itemsToSend = List<BufferedItem<T>>.from(_items);
    _items.clear();
    _bufferSize = 0;

    if (itemsToSend.isEmpty) {
      _options.log(
        SentryLevel.debug,
        '$InMemoryTelemetryBuffer<$T>: No data to flush.',
      );
      return null;
    }

    try {
      return _flusher.flush(itemsToSend);
    } catch (error) {
      _options.log(
        SentryLevel.error,
        '$InMemoryTelemetryBuffer<$T>: Failed to flush items: $error',
      );
      return null;
    }
  }
}
