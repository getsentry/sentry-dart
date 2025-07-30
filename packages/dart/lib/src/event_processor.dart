import 'dart:async';

import 'hint.dart';
import 'protocol.dart';

/// [EventProcessor]s are callbacks that run for every event. They can either
/// return a new event which in most cases means just adding data *or* return
/// null in case the event will be dropped and not sent.
abstract class EventProcessor {
  FutureOr<SentryEvent?> apply(
    SentryEvent event,
    Hint hint,
  );
}
