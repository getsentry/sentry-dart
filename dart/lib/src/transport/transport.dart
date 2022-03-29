import 'dart:async';

import '../../sentry.dart';

/// A transport is in charge of sending the event/envelope either via http
/// or caching in the disk.
abstract class Transport {
  Future<SentryId?> send(SentryEnvelope envelope);

  ClientReportRecorder get recorder;
}
