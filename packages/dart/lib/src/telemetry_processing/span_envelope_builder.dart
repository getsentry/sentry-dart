import '../../sentry.dart';

import 'envelope_builder.dart';
import 'telemetry_buffer.dart';

/// Groups spans by segment, one envelope per segment.
class SpanEnvelopeBuilder implements EnvelopeBuilder<Span> {
  final SentryOptions _options;

  SpanEnvelopeBuilder(this._options);

  @override
  List<SentryEnvelope> build(List<BufferedItem<Span>> items) {
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

  Map<String, List<BufferedItem<Span>>> _groupBySegment(
    List<BufferedItem<Span>> items,
  ) {
    final groups = <String, List<BufferedItem<Span>>>{};
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
