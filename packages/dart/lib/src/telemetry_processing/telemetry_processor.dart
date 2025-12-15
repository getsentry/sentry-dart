import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry.dart';
import 'in_memory_telemetry_buffer.dart';
import 'log_envelope_builder.dart';
import 'span_envelope_builder.dart';
import 'telemetry_buffer.dart';
import 'telemetry_item.dart';

/// Abstract interface for telemetry processing.
///
/// The TelemetryProcessor deals with sending telemetry data to Sentry.
/// It manages buffering, and in the future will handle rate-limiting,
/// client reports, and priority-queued sending of buffered telemetry.
@internal
abstract class TelemetryProcessor {
  /// Add a telemetry item to be sent to Sentry.
  void add(TelemetryItem item);

  /// Flush all buffered telemetry data.
  FutureOr<void> flush();
}

/// No-op implementation - does nothing.
/// Used before SDK is initialized or when telemetry is disabled.
@internal
class NoOpTelemetryProcessor implements TelemetryProcessor {
  @override
  void add(TelemetryItem item) {}

  @override
  FutureOr<void> flush() {}
}

/// Default telemetry processor.
///
/// Owns the [TransportDispatcher] and coordinates buffering and dispatch.
@internal
class DefaultTelemetryProcessor implements TelemetryProcessor {
  final Map<TelemetryType, TelemetryBuffer> _buffers = {};

  /// Creates the default telemetry processor with in-memory buffers.
  factory DefaultTelemetryProcessor(SentryOptions options) {
    final processor = DefaultTelemetryProcessor._();

    // TODO(next-pr): add span-first flag
    processor._registerBuffer(
        InMemoryTelemetryBuffer<Span>(
            logger: options.log,
            envelopeBuilder: SpanEnvelopeBuilder(options),
            transport: options.transport),
        TelemetryType.span);

    if (options.enableLogs) {
      processor._registerBuffer(
          InMemoryTelemetryBuffer<SentryLog>(
              logger: options.log,
              envelopeBuilder: LogEnvelopeBuilder(options),
              transport: options.transport),
          TelemetryType.log);
    }

    return processor;
  }

  DefaultTelemetryProcessor._();

  @override
  void add(TelemetryItem item) {
    final buffer = _buffers[item.type];
    if (buffer != null) {
      buffer.add(item);
    }
  }

  void _registerBuffer(TelemetryBuffer buffer, TelemetryType type) {
    _buffers[type] = buffer;
  }

  @override
  FutureOr<void> flush() {
    final results = _buffers.values.map((buffer) => buffer.flush()).toList();

    final futures = <Future<void>>[];
    for (final result in results) {
      if (result is Future<void>) {
        futures.add(result);
      }
    }

    // If all are sync, preserve sync behavior (no Future allocation).
    if (futures.isEmpty) return null;

    return Future.wait(futures).then((_) {});
  }
}
