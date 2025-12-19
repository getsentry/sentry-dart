import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry.dart';
import '../spans_v2/sentry_span_v2.dart';
import 'json_encodable.dart';
import 'telemetry_buffer.dart';

/// Manages buffering and sending of telemetry data to Sentry.
abstract class TelemetryProcessor {
  /// Adds a recording span to the buffer.
  void addSpan(RecordingSentrySpanV2 span);

  /// Adds a log to the buffer.
  void addLog(SentryLog log);

  /// Clears all buffers which sends any pending telemetry data.
  FutureOr<void> flush();
}

/// Manages buffering and sending of telemetry data to Sentry.
class DefaultTelemetryProcessor implements TelemetryProcessor {
  final SdkLogCallback _logger;

  /// Buffer for span telemetry data.
  @visibleForTesting
  TelemetryBuffer<RecordingSentrySpanV2>? spanBuffer;

  /// Buffer for log telemetry data.
  @visibleForTesting
  TelemetryBuffer<SentryLog>? logBuffer;

  DefaultTelemetryProcessor(
    this._logger, {
    this.spanBuffer,
    this.logBuffer,
  });

  @override
  void addSpan(RecordingSentrySpanV2 span) => _add(span);

  @override
  void addLog(SentryLog log) => _add(log);

  void _add<T extends JsonEncodable>(T item) {
    final buffer = switch (item) {
      RecordingSentrySpanV2 _ => spanBuffer,
      SentryLog _ => logBuffer,
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
    _logger(SentryLevel.debug, 'TelemetryProcessor: Clearing buffers');

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
  void addSpan(SentrySpanV2 span) {}

  @override
  void addLog(SentryLog log) {}

  @override
  FutureOr<void> flush() {}
}
