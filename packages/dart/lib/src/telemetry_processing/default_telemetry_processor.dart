import 'dart:async';

import '../../sentry.dart';
import 'in_memory_telemetry_buffer.dart';
import 'log_envelope_builder.dart';
import 'span_envelope_builder.dart';
import 'telemetry_buffer.dart';
import 'telemetry_item.dart';
import 'telemetry_processor.dart';

class DefaultTelemetryProcessor implements TelemetryProcessor {
  final Map<TelemetryType, TelemetryBuffer> _buffers = {};

  DefaultTelemetryProcessor._();

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
