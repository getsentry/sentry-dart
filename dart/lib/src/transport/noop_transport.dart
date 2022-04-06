import 'dart:async';

import '../sentry_envelope.dart';

import '../protocol.dart';
import 'transport.dart';
import '../client_reports/discard_reason.dart';
import 'data_category.dart';

class NoOpTransport implements Transport {
  @override
  Future<SentryId?> send(SentryEnvelope envelope) async => null;

  @override
  void recordLostEvent(DiscardReason reason, DataCategory category) {}
}
