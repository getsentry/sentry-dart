import 'dart:async';

import '../sentry_envelope.dart';
import '../protocol.dart';

/// A transport is in charge of sending the event/envelope either via http
/// or caching in the disk.
abstract class Transport {
  Future<SentryId?> send(SentryEnvelope envelope);
}

abstract class EventTransport {
  Future<SentryId?> sendEvent(SentryEvent event);
}
