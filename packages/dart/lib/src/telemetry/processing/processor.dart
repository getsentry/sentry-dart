import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../../utils/internal_logger.dart';
import '../span/sentry_span_v2.dart';
import 'buffer.dart';

/// Interface for processing and buffering telemetry data before sending.
///
/// Implementations collect spans and logs, buffering them until flushed.
/// This enables batching of telemetry data for efficient transport.
abstract class TelemetryProcessor {
  /// Adds a span to be processed and buffered.
  void addSpan(RecordingSentrySpanV2 span);

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
/// Spans and logs are dispatched to their respective [TelemetryBuffer]
/// instances. If no buffer is registered for a telemetry type, items are
/// dropped with a warning.
class DefaultTelemetryProcessor implements TelemetryProcessor {
  /// The buffer for span data, or `null` if span buffering is disabled.
  @visibleForTesting
  TelemetryBuffer<RecordingSentrySpanV2>? spanBuffer;

  /// The buffer for log data, or `null` if log buffering is disabled.
  @visibleForTesting
  TelemetryBuffer<SentryLog>? logBuffer;

  /// The buffer for metric data, or `null` if metric buffering is disabled.
  @visibleForTesting
  TelemetryBuffer<SentryMetric>? metricBuffer;

  DefaultTelemetryProcessor({
    this.spanBuffer,
    this.logBuffer,
    this.metricBuffer,
  });

  @override
  void addSpan(RecordingSentrySpanV2 span) {
    if (spanBuffer == null) {
      internalLogger.warning(
        '$runtimeType: No buffer registered for ${span.runtimeType} - item was dropped',
      );
      return;
    }
    spanBuffer!.add(span);
  }

  @override
  void addLog(SentryLog log) {
    if (logBuffer == null) {
      internalLogger.warning(
        '$runtimeType: No buffer registered for ${log.runtimeType} - item was dropped',
      );
      return;
    }
    logBuffer!.add(log);
    internalLogger.debug(() =>
        '$runtimeType: Log "${log.body}" (${log.level.name}) added to buffer');
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
    internalLogger.debug(() =>
        '$runtimeType: Metric "${metric.name}" (${metric.value}) added to buffer');
  }

  @override
  FutureOr<void> flush() {
    internalLogger.debug('$runtimeType: Clearing buffers');

    final results = <FutureOr<void>>[
      spanBuffer?.flush(),
      logBuffer?.flush(),
      metricBuffer?.flush(),
    ];

    final futures = results.whereType<Future>().toList();
    if (futures.isEmpty) {
      return null;
    }

    return Future.wait(futures).then((_) {});
  }
}

class NoOpTelemetryProcessor implements TelemetryProcessor {
  @override
  void addSpan(RecordingSentrySpanV2 span) {}

  @override
  void addLog(SentryLog log) {}

  @override
  void addMetric(SentryMetric log) {}

  @override
  FutureOr<void> flush() {}
}
