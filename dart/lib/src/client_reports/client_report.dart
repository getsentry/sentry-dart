import 'package:meta/meta.dart';

import 'discarded_event.dart';
import '../utils.dart';

@internal
class ClientReport {
  ClientReport(this.timestamp, this.discardedEvents);

  final DateTime timestamp;
  final List<DiscardedEvent> discardedEvents;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    json['timestamp'] = formatDateAsIso8601WithMillisPrecision(timestamp);

    final eventsJson = discardedEvents
        .map((e) => e.toJson())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (eventsJson.isNotEmpty) {
      json['discarded_events'] = eventsJson;
    }

    return json;
  }
}
