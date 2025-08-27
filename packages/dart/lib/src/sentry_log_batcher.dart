import 'dart:async';
import 'sentry_options.dart';
import 'protocol/sentry_log.dart';
import 'protocol/sentry_level.dart';
import 'sentry_envelope.dart';
import 'utils.dart';
import 'package:meta/meta.dart';

@internal
class SentryLogBatcher {
  SentryLogBatcher(
    this._options, {
    Duration? flushTimeout,
    int? maxBufferSizeBytes,
  })  : _flushTimeout = flushTimeout ?? Duration(seconds: 5),
        _maxBufferSizeBytes = maxBufferSizeBytes ??
            1024 * 1024; // 1MB default per BatchProcessor spec

  final SentryOptions _options;
  final Duration _flushTimeout;
  final int _maxBufferSizeBytes;

  // Store encoded log data instead of raw logs to avoid re-serialization
  final List<List<int>> _encodedLogs = [];
  int _encodedLogsSize = 0;

  Timer? _flushTimer;

  /// Adds a log to the buffer.
  void addLog(SentryLog log) {
    try {
      final encodedLog = utf8JsonEncoder.convert(log.toJson());

      _encodedLogs.add(encodedLog);
      _encodedLogsSize += encodedLog.length;

      // Flush if size threshold is reached
      if (_encodedLogsSize >= _maxBufferSizeBytes) {
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
        'Failed to encode log: $error',
      );
    }
  }

  /// Flushes the buffer immediately, sending all buffered logs.
  void flush() {
    _performFlushLogs();
  }

  void _startTimer() {
    _flushTimer = Timer(_flushTimeout, () {
      _options.log(
        SentryLevel.debug,
        'SentryLogBatcher: Timer fired, calling performCaptureLogs().',
      );
      _performFlushLogs();
    });
  }

  void _performFlushLogs() {
    // Reset timer state first
    _flushTimer?.cancel();
    _flushTimer = null;

    // Reset buffer on function exit
    final logsToSend = List<List<int>>.from(_encodedLogs);
    _encodedLogs.clear();
    _encodedLogsSize = 0;

    if (logsToSend.isEmpty) {
      _options.log(
        SentryLevel.debug,
        'SentryLogBatcher: No logs to flush.',
      );
      return;
    }

    try {
      final envelope = SentryEnvelope.fromLogsData(logsToSend, _options.sdk);
      _options.transport.send(envelope);
    } catch (error) {
      _options.log(
        SentryLevel.error,
        'Failed to send batched logs: $error',
      );
    }
  }
}
