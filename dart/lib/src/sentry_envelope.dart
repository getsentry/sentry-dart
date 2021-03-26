import 'sentry_envelope_header.dart';
import 'sentry_envelope_item.dart';
import 'protocol/sentry_event.dart';
import 'protocol/sdk_version.dart';

class SentryEnvelope {
  SentryEnvelope(this.header, this.items);

  final SentryEnvelopeHeader header;
  final List<SentryEnvelopeItem> items;

  static SentryEnvelope fromEvent(SentryEvent event, SdkVersion sdkVersion) {
    return SentryEnvelope(SentryEnvelopeHeader(event.eventId, sdkVersion),
        [SentryEnvelopeItem.fromEvent(event)]);
  }

  String serialize() {
    return '';
  }
}
