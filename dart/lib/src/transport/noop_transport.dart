import 'dart:async';

import '../sentry_envelope.dart';

import '../protocol.dart';
import 'transport.dart';

class NoOpTransport implements Transport {
  @override
  Future<SentryId> sendSentryEvent(SentryEvent event) =>
      Future.value(SentryId.empty());

  @override
  Future<SentryId> sendSentryEnvelope(SentryEnvelope envelope) =>
      Future.value(SentryId.empty());
}
