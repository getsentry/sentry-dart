import 'sentry_envelope_header.dart';
import 'sentry_envelope_item.dart';

class SentryEnvelope {
  SentryEnvelope(this.header, this.items);

  final SentryEnvelopeHeader header;
  final List<SentryEnvelopeItem> items;
}
