import 'dart:async';

import '../protocol.dart';

/// A transport is in charge of sending the event either via http
/// or caching in the disk.
abstract class Transport {
  Future<SentryId> send(SentryEvent event);
}
