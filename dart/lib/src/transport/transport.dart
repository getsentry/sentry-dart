import 'dart:async';

import '../sentry_envelope.dart';
import '../protocol.dart';
import '../client_reports/discard_reason.dart';
import 'data_category.dart';

/// A transport is in charge of sending the event/envelope either via http
/// or caching in the disk.
abstract class Transport {
  Future<SentryId?> send(SentryEnvelope envelope);

  void recordLostEvent(final DiscardReason reason, final DataCategory category);
}
