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
  void addMetric(SentryMetric log);

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
  @visibleForTesting
  TelemetryBuffer<SentryLog>? logBuffer;

  /// The buffer for metric data, or `null` if metric buffering is disabled.
  @visibleForTesting
  TelemetryBuffer<SentryMetric>? metricBuffer;

  DefaultTelemetryProcessor({
    this.logBuffer,
    this.metricBuffer,
  });

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
  void addMetric(SentryMetric metric) {
    if (metricBuffer == null) {
      internalLogger.warning(
        '$runtimeType: No buffer registered for ${metric.runtimeType} - item was dropped',
      );
      return;
    }

    metricBuffer!.add(metric);
  }

  @override
  FutureOr<void> flush() {
    internalLogger.debug('$runtimeType: Clearing buffers');

    final results = [logBuffer?.flush(), metricBuffer?.flush()];

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
