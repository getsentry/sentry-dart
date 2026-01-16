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

  DefaultTelemetryProcessor({
    this.spanBuffer,
    this.logBuffer,
  });

  @override
  void addSpan(RecordingSentrySpanV2 span) => _add(span);

  @override
  void addLog(SentryLog log) => _add(log);

  void _add(dynamic item) {
    final buffer = switch (item) {
      RecordingSentrySpanV2 _ => spanBuffer,
      SentryLog _ => logBuffer,
      _ => null,
    };

    if (buffer == null) {
      internalLogger.warning(
        '$runtimeType: No buffer registered for ${item.runtimeType} - item was dropped',
      );
      return;
    }

    buffer.add(item);
  }

  @override
  FutureOr<void> flush() {
    internalLogger.debug('$runtimeType: Clearing buffers');

    final results = <FutureOr<void>>[
      spanBuffer?.flush(),
      logBuffer?.flush(),
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
  FutureOr<void> flush() {}
}
