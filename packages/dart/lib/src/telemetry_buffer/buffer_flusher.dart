import 'dart:async';
import 'dart:io';

import '../../sentry.dart';

/// A buffered item containing both the raw item and its encoded bytes.
/// This allows accurate size tracking while preserving access to raw data
/// for grouping/inspection by flushers.
class BufferedItem<T> {
  final T item;
  final List<int> encoded;

  BufferedItem(this.item, this.encoded);
}

/// Flusher for processing buffered telemetry items.
/// Responsible for grouping, envelope creation, and sending.
abstract class BufferFlusher<T> {
  FutureOr<void> flush(List<BufferedItem<T>> items);
}

/// Flusher for logs: no grouping, single envelope.
class LogBufferFlusher implements BufferFlusher<SentryLog> {
  final SentryOptions _options;

  LogBufferFlusher(this._options);

  @override
  FutureOr<void> flush(List<BufferedItem<SentryLog>> items) {
    if (items.isEmpty) return null;

    final encoded = items.map((i) => i.encoded).toList();
    final envelope = SentryEnvelope.fromLogsData(encoded, _options.sdk);
    return _options.transport.send(envelope).then((_) => null);
  }
}

/// Flusher for spans: groups by segment, one envelope per group with trace context.
class SpanBufferFlusher implements BufferFlusher<Span> {
  final SentryOptions _options;

  SpanBufferFlusher(this._options);

  @override
  FutureOr<void> flush(List<BufferedItem<Span>> items) async {
    if (items.isEmpty) return;

    final groups = _groupBySegment(items);

    for (final entry in groups.entries) {
      try {
        final encoded = entry.value.map((i) => i.encoded).toList();
        final traceContext = _createTraceContext(entry.value.first.item);
        final envelope = SentryEnvelope.fromSpansData(
          encoded,
          _options.sdk,
          dsn: _options.dsn,
          traceContext: traceContext,
        );
        await _options.transport.send(envelope);
      } catch (error) {
        _options.log(
          SentryLevel.error,
          'SpanBufferFlusher: Failed to send span group ${entry.key}: $error',
        );
      }
    }
  }

  /// Groups buffered spans by their segment (traceId + segmentSpanId).
  Map<String, List<BufferedItem<Span>>> _groupBySegment(
    List<BufferedItem<Span>> items,
  ) {
    final groups = <String, List<BufferedItem<Span>>>{};
    for (final buffered in items) {
      final key = _segmentKey(buffered.item);
      groups.putIfAbsent(key, () => []).add(buffered);
    }
    return groups;
  }

  /// Returns a unique key for the segment this span belongs to.
  String _segmentKey(Span span) {
    final segment = span.parentSpan ?? span;
    final json = segment.toJson();
    final traceId = json['trace_id'];
    return traceId == null ? '_' : '$traceId-${segment.spanId}';
  }

  /// Creates a trace context header from the segment span.
  SentryTraceContextHeader? _createTraceContext(Span span) {
    final segment = span.parentSpan ?? span;
    final json = segment.toJson();
    final traceId = json['trace_id'];
    final publicKey = _options.parsedDsn.publicKey;

    if (traceId == null) return null;

    return SentryTraceContextHeader(
      SentryId.fromId(traceId),
      publicKey,
      release: _options.release,
      environment: _options.environment,
    );
  }
}
