import 'package:meta/meta.dart';

import 'discarded_event.dart';

@internal
class ClientReport {
  ClientReport(this.timestamp, this.discardedEvents);

  final DateTime? timestamp;
  final List<DiscardedEvent> discardedEvents;
}
