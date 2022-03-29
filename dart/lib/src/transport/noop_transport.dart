import 'dart:async';

import '../../sentry.dart';

class NoOpTransport implements Transport {
  @override
  Future<SentryId?> send(SentryEnvelope envelope) async => null;

  @override
  ClientReportRecorder get recorder => ClientReportRecorder();
}
