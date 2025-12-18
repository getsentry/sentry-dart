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

/// All items in a single envelope.
// TODO(next-pr): finish impl
class LogEnvelopeBuilder extends SingleEnvelopeBuilder<SentryLog> {
  LogEnvelopeBuilder() : super((items) => throw UnimplementedError());
}

/// Groups spans by segment, one envelope per segment.
// TODO(next-pr): finish impl
class SpanEnvelopeBuilder implements EnvelopeBuilder<Span> {
  @override
  List<SentryEnvelope> build(List<BufferedItem<Span>> items) {
    throw UnimplementedError();
  }
}
