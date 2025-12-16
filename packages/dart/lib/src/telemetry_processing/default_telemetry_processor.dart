import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry.dart';
import 'in_memory_telemetry_buffer.dart';
import 'single_envelope_builder.dart';
import 'span_envelope_builder.dart';
import 'telemetry_buffer.dart';
import 'telemetry_item.dart';
import 'telemetry_processor.dart';

class DefaultTelemetryProcessor implements TelemetryProcessor {
  final SentryOptions _options;
  final Map<TelemetryType, TelemetryBuffer> _buffers = {};

  @visibleForTesting
  Map<TelemetryType, TelemetryBuffer> get buffers => _buffers;

  DefaultTelemetryProcessor._(this._options);

  factory DefaultTelemetryProcessor(SentryOptions options) {
    final processor = DefaultTelemetryProcessor._(options);

    // TODO(next-pr): add span-first flag
    processor.registerBuffer(
        InMemoryTelemetryBuffer<Span>(
            logger: options.log,
            envelopeBuilder: SpanEnvelopeBuilder(options),
            transport: options.transport),
        TelemetryType.span);

    if (options.enableLogs) {
      processor.registerBuffer(
          InMemoryTelemetryBuffer<SentryLog>(
              logger: options.log,
              envelopeBuilder: LogEnvelopeBuilder(options),
              transport: options.transport),
          TelemetryType.log);
    }

    options.log(
      SentryLevel.debug,
      'DefaultTelemetryProcessor: Successfully initialized',
    );

    return processor;
  }

  @override
  void add(TelemetryItem item) {
    final buffer = _buffers[item.type];
    if (buffer != null) {
      buffer.add(item);
    } else {
      _options.log(
        SentryLevel.warning,
        'DefaultTelemetryProcessor: No buffer registered for telemetry type ${item.type.name} - item was dropped',
      );
    }
  }

  @visibleForTesting
  void registerBuffer(TelemetryBuffer buffer, TelemetryType type) {
    _buffers[type] = buffer;
    _options.log(
      SentryLevel.debug,
      'DefaultTelemetryProcessor: Registered buffer for ${type.name}',
    );
  }

  @override
  FutureOr<void> flush() {
    _options.log(
      SentryLevel.debug,
      'DefaultTelemetryProcessor: Flushing ${_buffers.length} buffer(s)',
    );

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
