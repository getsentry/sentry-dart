import 'package:sentry/sentry.dart';

class MockTransport implements Transport {
  List<SentryEvent> events = [];
  List<SentryEnvelope> envelopes = [];

  bool called(int calls) {
    return events.length == calls;
  }

  @override
  Future<SentryId> sendSentryEvent(SentryEvent event) async {
    events.add(event);
    return event.eventId;
  }

  @override
  Future<SentryId> sendSentryEnvelope(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    return envelope.header.eventId ?? SentryId.empty();
  }
}
