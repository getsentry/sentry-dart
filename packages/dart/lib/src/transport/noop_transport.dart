import 'dart:async';

import '../envelope/sentry_envelope.dart';

import '../protocol.dart';
import 'transport.dart';

class NoOpTransport implements Transport {
  @override
  Future<SentryId?> send(SentryEnvelope envelope) async => null;
}
