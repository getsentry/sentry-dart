import 'package:meta/meta.dart';

import '../../sentry.dart';
import 'telemetry_buffer.dart';
import 'telemetry_item.dart';

@internal
abstract class EnvelopeBuilder<T extends TelemetryItem> {
  /// May return multiple envelopes (e.g., one per segment for spans).
  List<SentryEnvelope> build(List<EncodedTelemetryItem<T>> items);
}

/// All items in a single envelope.
class SingleEnvelopeBuilder<T extends TelemetryItem>
    implements EnvelopeBuilder<T> {
  final SentryEnvelope Function(List<EncodedTelemetryItem<T>> items) _create;

  SingleEnvelopeBuilder(this._create);

  @override
  List<SentryEnvelope> build(List<EncodedTelemetryItem<T>> items) =>
      items.isEmpty ? [] : [_create(items)];
}

class LogEnvelopeBuilder extends SingleEnvelopeBuilder<SentryLog> {
  LogEnvelopeBuilder(SentryOptions options)
      : super((items) => SentryEnvelope.fromLogsData(
              items.map((i) => i.encoded).toList(),
              options.sdk,
            ));
}

/// Groups spans by segment, one envelope per segment.
class SpanEnvelopeBuilder implements EnvelopeBuilder<Span> {
  final SentryOptions _options;

  SpanEnvelopeBuilder(this._options);

  @override
  List<SentryEnvelope> build(List<EncodedTelemetryItem<Span>> items) {
    if (items.isEmpty) return [];

    final groups = _groupBySegment(items);
    final envelopes = <SentryEnvelope>[];

    for (final entry in groups.entries) {
      final encoded = entry.value.map((i) => i.encoded).toList();
      final traceContext = _createTraceContext(entry.value.first.item);
      final envelope = SentryEnvelope.fromSpansData(
        encoded,
        _options.sdk,
        dsn: _options.dsn,
        traceContext: traceContext,
      );
      envelopes.add(envelope);
    }

    return envelopes;
  }

  Map<String, List<EncodedTelemetryItem<Span>>> _groupBySegment(
    List<EncodedTelemetryItem<Span>> items,
  ) {
    final groups = <String, List<EncodedTelemetryItem<Span>>>{};
    for (final buffered in items) {
      final segment = buffered.item.segmentSpan;
      final key = '${segment.traceId}-${segment.spanId}';
      groups.putIfAbsent(key, () => []).add(buffered);
    }
    return groups;
  }

  SentryTraceContextHeader? _createTraceContext(Span span) {
    final segment = span.segmentSpan;
    final publicKey = _options.parsedDsn.publicKey;

    return SentryTraceContextHeader(
      segment.traceId,
      publicKey,
      release: _options.release,
      environment: _options.environment,
    );
  }
}
