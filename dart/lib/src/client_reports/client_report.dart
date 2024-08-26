import 'package:meta/meta.dart';

import '../../sentry.dart';
import 'discarded_event.dart';
import '../utils.dart';

@internal
class ClientReport implements SentryEnvelopeItemPayload {
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

  @override
  Future<dynamic> getPayload() => Future.value(toJson());
}
