import 'dart:async';

import '../sentry.dart';

abstract class TelemetryPayload {
  Map<String, dynamic> toJson();
}

abstract class TelemetryBuffer<T extends Telemetry> {
  void add(T item);
  FutureOr<void> flush();
}

class NoOpTelemetryBuffer<T extends TelemetryPayload> extends TelemetryBuffer<T> {
  @override
  void add(T item) {}

  @override
  FutureOr<void> flush() {}
}

class InMemoryTelemetryBuffer<T extends TelemetryPayload> extends TelemetryBuffer<T> {
  final SentryEnvelope Function(List<List<int>>) toEnvelope;
  final SentryOptions _options;
  final Duration _flushTimeout;
  final int _maxBufferSizeBytes;
  Timer? _flushTimer;
  // Store encoded telemetry data instead of raw telemetry to avoid re-serialization
  final List<List<int>> _encodedTelemetry = [];
  int _encodedTelemetrySize = 0;

  InMemoryTelemetryBuffer(
    this._options, {
    required this.toEnvelope,
    Duration? flushTimeout,
    int? maxBufferSizeBytes,
  })  : _flushTimeout = flushTimeout ?? Duration(seconds: 5),
        _maxBufferSizeBytes = maxBufferSizeBytes ??
            1024 * 1024; // 1MB default per Mobile Buffer spec

  /// Adds a telemetry to the buffer.
  @override
  void add(T telemetry) {
    try {
      final encodedTelemetry = utf8JsonEncoder.convert(telemetry.toJson());

      _encodedTelemetry.add(encodedTelemetry);
      _encodedTelemetrySize += encodedTelemetry.length;

      // Flush if size threshold is reached
      if (_encodedTelemetrySize >= _maxBufferSizeBytes) {
        // Buffer size exceeded, flush immediately
        _performFlushLogs();
      } else if (_flushTimer == null) {
        // Start timeout only when first item is added
        _startTimer();
      }
      // Note: We don't restart the timer on subsequent additions per spec
    } catch (error) {
      _options.log(
        SentryLevel.error,
        '$InMemoryTelemetryBuffer for $T: Failed to encode log with error $error',
      );
    }
  }

  /// Flushes the buffer immediately, sending all buffered telemetry.
  @override
  FutureOr<void> flush() => _performFlushLogs();

  void _startTimer() {
    _flushTimer = Timer(_flushTimeout, () {
      _options.log(
        SentryLevel.debug,
        '$InMemoryTelemetryBuffer for $T: Timer fired, calling performCaptureLogs().',
      );
      _performFlushLogs();
    });
  }

  FutureOr<void> _performFlushLogs() {
    // Reset timer state first
    _flushTimer?.cancel();
    _flushTimer = null;

    // Reset buffer on function exit
    final telemetryToSend = List<List<int>>.from(_encodedTelemetry);
    _encodedTelemetry.clear();
    _encodedTelemetrySize = 0;

    if (telemetryToSend.isEmpty) {
      _options.log(
        SentryLevel.debug,
        '$InMemoryTelemetryBuffer for $T: No logs to flush.',
      );
    } else {
      try {
        final envelope = toEnvelope(telemetryToSend);
        return _options.transport.send(envelope).then((_) => null);
      } catch (error) {
        _options.log(
          SentryLevel.error,
          '$InMemoryTelemetryBuffer for $T: Failed to create envelope for batched logs with error $error',
        );
      }
    }
  }
}
