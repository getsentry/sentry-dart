import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../../utils/internal_logger.dart';
import 'buffer.dart';

/// Interface for processing and buffering telemetry data before sending.
///
/// Implementations collect logs, buffering them until flushed.
/// This enables batching of telemetry data for efficient transport.
abstract class TelemetryProcessor {
  /// Adds a log to be processed and buffered.
  void addLog(SentryLog log);

  /// Flushes all buffered telemetry data.
  ///
  /// Returns a [Future] if any buffer performs async flushing, otherwise
  /// returns synchronously.
  FutureOr<void> flush();
}

/// Default telemetry processor that routes items to type-specific buffers.
///
/// Logs are dispatched to their respective [TelemetryBuffer]
/// instances. If no buffer is registered for a telemetry type, items are
/// dropped with a warning.
class DefaultTelemetryProcessor implements TelemetryProcessor {
  /// The buffer for log data, or `null` if log buffering is disabled.
  final TelemetryBuffer<SentryLog>? _logBuffer;

  @visibleForTesting
  TelemetryBuffer<SentryLog>? get logBuffer => _logBuffer;

  DefaultTelemetryProcessor({
    TelemetryBuffer<SentryLog>? logBuffer,
  }) : _logBuffer = logBuffer;

  @override
  void addLog(SentryLog log) {
    if (logBuffer == null) {
      internalLogger.warning(
        '$runtimeType: No buffer registered for ${log.runtimeType} - item was dropped',
      );
      return;
    }

    logBuffer!.add(log);
  }

  @override
  FutureOr<void> flush() {
    internalLogger.debug('$runtimeType: Clearing buffers');

    final result = logBuffer?.flush();

    if (result is Future) {
      return result;
    }

    return null;
  }
}

class NoOpTelemetryProcessor implements TelemetryProcessor {
  @override
  void addLog(SentryLog log) {}

  @override
  FutureOr<void> flush() {}
}
