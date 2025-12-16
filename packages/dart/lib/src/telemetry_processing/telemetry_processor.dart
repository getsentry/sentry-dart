import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry.dart';
import 'telemetry_buffer.dart';

/// Manages buffering and sending of telemetry data to Sentry.
abstract class TelemetryProcessor {
  void addSpan(Span span);
  void addLog(SentryLog log);
  FutureOr<void> flush();
}

/// Manages buffering and sending of telemetry data to Sentry.
///
/// Creates and manages buffers internally based on [SentryOptions] configuration.
/// Buffers are only created when their respective features are enabled.
class DefaultTelemetryProcessor implements TelemetryProcessor {
  final SentryOptions _options;
  final SdkLogCallback _logger;

  /// Buffer for span telemetry data.
  ///
  /// Only created if tracing is enabled in options.
  @visibleForTesting
  TelemetryBuffer<Span>? spanBuffer;

  /// Buffer for log telemetry data.
  ///
  /// Only created if logging is enabled in options.
  @visibleForTesting
  TelemetryBuffer<SentryLog>? logBuffer;

  DefaultTelemetryProcessor(this._options, this._logger) {
    _initBuffers();
  }

  void _initBuffers() {
    // TODO(next-pr): add span first flag
    spanBuffer = createSpanBuffer();
    _logger(SentryLevel.debug, 'TelemetryProcessor: Span buffer initialized');

    if (_options.enableLogs) {
      logBuffer = createLogBuffer();
      _logger(SentryLevel.debug, 'TelemetryProcessor: Log buffer initialized');
    }
  }

  /// Creates the span buffer.
  ///
  /// Can be overridden in subclasses or tests to provide a custom buffer.
  @visibleForTesting
  TelemetryBuffer<Span> createSpanBuffer() {
    throw UnimplementedError();
  }

  /// Creates the log buffer.
  ///
  /// Can be overridden in subclasses or tests to provide a custom buffer.
  @visibleForTesting
  TelemetryBuffer<SentryLog> createLogBuffer() {
    throw UnimplementedError();
  }

  /// Adds a span to the buffer for later transmission.
  ///
  /// If no span buffer is registered, the span is dropped
  /// and a warning is logged.
  @override
  void addSpan(Span span) {
    final buffer = spanBuffer;
    if (buffer != null) {
      buffer.add(span);
    } else {
      _logger(
        SentryLevel.warning,
        'TelemetryProcessor: No span buffer registered - span was dropped',
      );
    }
  }

  /// Adds a log to the buffer for later transmission.
  ///
  /// If no log buffer is registered, the log is dropped
  /// and a warning is logged.
  @override
  void addLog(SentryLog log) {
    final buffer = logBuffer;
    if (buffer != null) {
      buffer.add(log);
    } else {
      _logger(
        SentryLevel.warning,
        'TelemetryProcessor: No log buffer registered - log was dropped',
      );
    }
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
    ].whereType<FutureOr<void>>().toList();

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
