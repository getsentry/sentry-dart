import '../../sentry.dart';
import 'json_encodable.dart';
import 'telemetry_buffer.dart';

abstract class EnvelopeBuilder<T> {
  /// May return multiple envelopes (e.g., one per segment for spans).
  List<SentryEnvelope> build(List<BufferedItem<T>> items);
}

/// All items in a single envelope.
class SingleEnvelopeBuilder<T extends JsonEncodable>
    implements EnvelopeBuilder<T> {
  final SentryEnvelope Function(List<BufferedItem<T>> items) _create;

  SingleEnvelopeBuilder(this._create);

  @override
  List<SentryEnvelope> build(List<BufferedItem<T>> items) =>
      items.isEmpty ? [] : [_create(items)];
}

class LogEnvelopeBuilder extends SingleEnvelopeBuilder<SentryLog> {
  LogEnvelopeBuilder(SdkVersion sdk)
      : super((items) => SentryEnvelope.fromLogsData(
              items.map((i) => i.encoded).toList(),
              sdk,
            ));
}

typedef TraceContextFactory = SentryTraceContextHeader? Function(Span span);

/// Groups spans by segment, one envelope per segment.
class SpanEnvelopeBuilder implements EnvelopeBuilder<Span> {
  final TraceContextFactory _traceContextFactory;
  final SdkVersion _sdkVersion;
  final String? _dsn;

  SpanEnvelopeBuilder(this._traceContextFactory, this._sdkVersion, this._dsn);

  @override
  List<SentryEnvelope> build(List<BufferedItem<Span>> items) {
    if (items.isEmpty) return [];

    final groups = _groupBySegment(items);
    final envelopes = <SentryEnvelope>[];

    for (final entry in groups.entries) {
      final encoded = entry.value.map((i) => i.encoded).toList();
      final traceContext = _traceContextFactory(entry.value.first.item);
      final envelope = SentryEnvelope.fromSpansData(
        encoded,
        _sdkVersion,
        dsn: _dsn,
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
}
