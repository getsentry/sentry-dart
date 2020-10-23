import 'dart:async';

import 'package:sentry/sentry.dart';

class NoOpTransport implements Transport {
  @override
  Dsn get dsn => null;

  @override
  Future<SentryId> send(SentryEvent event) => Future.value(SentryId.empty());
}
