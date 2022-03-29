import 'discarded_event.dart';
import '../utils.dart';

class ClientReport {
  ClientReport(this.timestamp, this.discardedEvents);

  final DateTime? timestamp;
  final List<DiscardedEvent> discardedEvents;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (timestamp != null) {
      json['timestamp'] = formatDateAsIso8601WithMillisPrecision(timestamp!);
    }

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
