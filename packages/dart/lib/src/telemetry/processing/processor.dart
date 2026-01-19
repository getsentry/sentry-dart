import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../../utils/internal_logger.dart';
import '../metric/metric.dart';
import 'buffer.dart';

/// Interface for processing and buffering telemetry data before sending.
///
/// Implementations collect logs, buffering them until flushed.
/// This enables batching of telemetry data for efficient transport.
abstract class TelemetryProcessor {
  /// Adds a log to be processed and buffered.
  void addLog(SentryLog log);

  /// Adds a metric to be processed and buffered.
  void addMetric(SentryMetric metric);

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
  /// The buffer for metric data, or `null` if metric buffering is disabled.
  final TelemetryBuffer<SentryMetric>? _metricBuffer;
  
  
  @visibleForTesting
  TelemetryBuffer<SentryMetric>? get metricBuffer => _metricBuffer;

   /// The buffer for log data, or `null` if log buffering is disabled.
  final TelemetryBuffer<SentryLog>? _logBuffer;

  @visibleForTesting
  TelemetryBuffer<SentryLog>? get logBuffer => _logBuffer;

  DefaultTelemetryProcessor({
    TelemetryBuffer<SentryMetric>? metricBuffer,
    TelemetryBuffer<SentryLog>? logBuffer,
  }) : _metricBuffer = metricBuffer, 
       _logBuffer = logBuffer;

  @override
  void addLog(SentryLog log) {
    if (_logBuffer == null) {
      internalLogger.warning(
        '$runtimeType: No buffer registered for ${log.runtimeType} - item was dropped',
      );
      return;
    }

    _logBuffer!.add(log);
  }

  @override
  void addMetric(SentryMetric metric) {
    if (_metricBuffer == null) {
      internalLogger.warning(
        '$runtimeType: No buffer registered for ${metric.runtimeType} - item was dropped',
      );
      return;
    }

    _metricBuffer!.add(metric);
  }

  @override
  FutureOr<void> flush() {
    internalLogger.debug('$runtimeType: Clearing buffers');

    final results = [_logBuffer?.flush(), _metricBuffer?.flush()];

    final futures = results.whereType<Future>().toList();
    if (futures.isEmpty) {
      return null;
    }

    return Future.wait(futures).then((_) {});
  }
}

class NoOpTelemetryProcessor implements TelemetryProcessor {
  @override
  void addLog(SentryLog log) {}

  @override
  void addMetric(SentryMetric log) {}

  @override
  FutureOr<void> flush() {}
}
