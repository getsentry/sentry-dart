import 'dart:async';

import 'package:sentry/sentry.dart';

class NoOpTransport implements Transport {
  @override
  Dsn get dsn => null;

  @override
  String get origin => null;

  @override
  String get sdkIdentifier => null;

  @override
  Future<SentryId> send(SentryEvent event) => Future.value(SentryId.empty());
}
