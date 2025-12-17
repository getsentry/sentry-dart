import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry.dart';
import '../protocol/noop_span.dart';
import '../protocol/unset_span.dart';
import 'telemetry_buffer.dart';
import 'sentry_encodable.dart';

/// Manages buffering and sending of telemetry data to Sentry.
abstract class TelemetryProcessor {
  void addSpan(Span span);
  void addLog(SentryLog log);
  FutureOr<void> flush();
}

/// Manages buffering and sending of telemetry data to Sentry.
class DefaultTelemetryProcessor implements TelemetryProcessor {
  final SdkLogCallback _logger;

  /// Buffer for span telemetry data.
  @visibleForTesting
  TelemetryBuffer<Span>? spanBuffer;

  /// Buffer for log telemetry data.
  @visibleForTesting
  TelemetryBuffer<SentryLog>? logBuffer;

  /// Creates a telemetry processor.
  DefaultTelemetryProcessor(
    this._logger, {
    this.spanBuffer,
    this.logBuffer,
  });

  /// Adds a span to the buffer for later transmission.
  ///
  /// If no span buffer is set, the span is dropped
  /// and a warning is logged.
  ///
  /// If span is [NoOpSpan] or [UnsetSpan] it is not added to the buffer.
  @override
  void addSpan(Span span) =>
      (span is NoOpSpan || span is UnsetSpan) ? null : _add(span);

  /// Adds a log to the buffer for later transmission.
  ///
  /// If no log buffer is set, the log is dropped
  /// and a warning is logged.
  @override
  void addLog(SentryLog log) => _add(log);

  void _add(SentryEncodable item) {
    final buffer = switch (item) {
      Span() => spanBuffer,
      SentryLog() => logBuffer,
      _ => null,
    };

    if (buffer == null) {
      _logger(
        SentryLevel.warning,
        'TelemetryProcessor: No buffer registered for ${item.runtimeType} - item was dropped',
      );
      return;
    }

    buffer.add(item);
  }

  /// Flushes all buffers, sending any pending telemetry data.
  ///
  /// Returns a [Future] that completes when all buffers have been flushed.
  /// Returns immediately if no buffers need flushing.
  @override
  FutureOr<void> flush() {
    _logger(SentryLevel.debug, 'TelemetryProcessor: Flushing buffers');

    final results = <FutureOr<void>>[
      spanBuffer?.flush(),
      logBuffer?.flush(),
    ];

    final futures = results.whereType<Future<void>>().toList();
    if (futures.isEmpty) {
      return null;
    }

    return Future.wait(futures).then((_) {});
  }
}

class NoOpTelemetryProcessor implements TelemetryProcessor {
  @override
  void addSpan(Span span) {}

  @override
  void addLog(SentryLog log) {}

  @override
  FutureOr<void> flush() {}
}
