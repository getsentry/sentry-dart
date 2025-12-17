import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry.dart';
import '../protocol/noop_span.dart';
import '../protocol/unset_span.dart';
import 'telemetry_buffer.dart';

/// Manages buffering and sending of telemetry data to Sentry.
abstract class TelemetryProcessor {
  /// Adds a span to the buffer for later transmission.
  void addSpan(Span span);

  /// Adds a log to the buffer for later transmission.
  void addLog(SentryLog log);

  /// Flushes all buffers, sending any pending telemetry data.
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

  DefaultTelemetryProcessor(
    this._logger, {
    this.spanBuffer,
    this.logBuffer,
  });

  @override
  void addSpan(Span span) =>
      (span is NoOpSpan || span is UnsetSpan) ? null : _add(span);

  @override
  void addLog(SentryLog log) => _add(log);

  void _add(dynamic item) {
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
