import 'package:sentry/sentry.dart';

class MockTransport implements Transport {
  List<SentryEnvelope> envelopes = [];

  bool called(int calls) {
    return envelopes.length == calls;
  }

  @override
  Future<SentryId> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    return envelope.header.eventId ?? SentryId.empty();
  }
}

class ThrowingTransport implements Transport {
  @override
  Future<SentryId> send(SentryEnvelope envelope) async {
    throw Exception('foo bar');
  }
}
