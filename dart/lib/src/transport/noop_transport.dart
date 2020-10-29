import 'dart:async';

import '../protocol.dart';
import 'transport.dart';

class NoOpTransport implements Transport {
  @override
  Future<SentryId> send(SentryEvent event) => Future.value(SentryId.empty());
}
