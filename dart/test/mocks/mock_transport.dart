import 'dart:convert';

import 'package:sentry/sentry.dart';

import 'no_such_method_provider.dart';

class MockTransport with NoSuchMethodProvider implements Transport {
  List<SentryEnvelope> envelopes = [];
  List<SentryEvent> events = [];
  int calls = 0;

  bool called(int calls) {
    return calls == calls;
  }

  @override
  Future<SentryId> send(SentryEnvelope envelope) async {
    calls++;

    envelopes.add(envelope);
    final event = await _eventFromEnvelope(envelope);
    events.add(event);

    return envelope.header.eventId ?? SentryId.empty();
  }

  Future<SentryEvent> _eventFromEnvelope(SentryEnvelope envelope) async {
    final envelopeItemData = <int>[];
    envelopeItemData.addAll(await envelope.items.first.envelopeItemStream());

    final envelopeItem = utf8.decode(envelopeItemData);
    final envelopeItemJson = jsonDecode(envelopeItem.split('\n').last);
    final envelopeMap = envelopeItemJson as Map<String, dynamic>;
    final requestJson = envelopeMap['request'] as Map<String, dynamic>?;

    // '_InternalLinkedHashMap<dynamic, dynamic>' is not a subtype of type 'Map<String, String>'
    final headersMap = requestJson?['headers'] as Map<String, dynamic>?;
    final newHeadersMap = <String, String>{};
    if (headersMap != null) {
      for (final entry in headersMap.entries) {
        newHeadersMap[entry.key] = entry.value as String;
      }
      envelopeMap['request']['headers'] = newHeadersMap;
    }

    final otherMap = requestJson?['other'] as Map<String, dynamic>?;
    final newOtherMap = <String, String>{};
    if (otherMap != null) {
      for (final entry in otherMap.entries) {
        newOtherMap[entry.key] = entry.value as String;
      }
      envelopeMap['request']['other'] = newOtherMap;
    }

    return SentryEvent.fromJson(envelopeMap);
  }

  void reset() {
    envelopes.clear();
    events.clear();
    calls = 0;
  }
}

class ThrowingTransport implements Transport {
  @override
  Future<SentryId> send(SentryEnvelope envelope) async {
    throw Exception('foo bar');
  }
}
