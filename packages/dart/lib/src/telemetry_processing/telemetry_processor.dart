import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry.dart';
import 'envelope_builder.dart';
import 'telemetry_buffer.dart';
import 'telemetry_item.dart';

/// Manages buffering and sending of telemetry data to Sentry.
abstract class TelemetryProcessor {
  void add<T extends TelemetryItem>(T item);
  FutureOr<void> flush();
}

class DefaultTelemetryProcessor implements TelemetryProcessor {
  final SentryOptions _options;
  final Map<Type, TelemetryBuffer> _buffers = {};

  @visibleForTesting
  Map<Type, TelemetryBuffer> get buffers => _buffers;

  DefaultTelemetryProcessor._(this._options);

  factory DefaultTelemetryProcessor(SentryOptions options) {
    final processor = DefaultTelemetryProcessor._(options);

    // TODO(next-pr): add span-first flag
    processor.registerBuffer(InMemoryTelemetryBuffer<Span>(
        logger: options.log,
        envelopeBuilder: SpanEnvelopeBuilder(options),
        transport: options.transport));

    if (options.enableLogs) {
      processor.registerBuffer(InMemoryTelemetryBuffer<SentryLog>(
          logger: options.log,
          envelopeBuilder: LogEnvelopeBuilder(options),
          transport: options.transport));
    }

    options.log(
      SentryLevel.debug,
      'DefaultTelemetryProcessor: Successfully initialized',
    );

    return processor;
  }

  @override
  void add<T extends TelemetryItem>(T item) {
    final buffer = _buffers[T];
    if (buffer != null) {
      buffer.add(item);
    } else {
      _options.log(
        SentryLevel.warning,
        'DefaultTelemetryProcessor: No buffer registered for telemetry type \'$T\' - item was dropped',
      );
    }
  }

  @visibleForTesting
  void registerBuffer<T extends TelemetryItem>(TelemetryBuffer<T> buffer) {
    _buffers[T] = buffer;
    _options.log(
      SentryLevel.debug,
      'DefaultTelemetryProcessor: Registered buffer for telemetry type \'$T\'',
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
