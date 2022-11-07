import 'dart:convert';

import 'package:sentry/sentry.dart';
import 'package:test/expect.dart';

class MockTransport implements Transport {
  List<SentryEnvelope> envelopes = [];
  List<SentryEvent> events = [];

  int _calls = 0;
  String _exceptions = '';

  int get calls {
    expect(_exceptions, isEmpty);
    return _calls;
  }

  bool called(int calls) {
    return calls == calls;
  }

  @override
  Future<SentryId> send(SentryEnvelope envelope) async {
    _calls++;

    // Exception here would be swallowed by Sentry, making it hard to find test
    // failure causes. Instead, we log them and check on access to [calls].
    try {
      envelopes.add(envelope);
      final event = await _eventFromEnvelope(envelope);
      events.add(event);
    } catch (e, stack) {
      _exceptions += '$e\n$stack\n\n';
      rethrow;
    }

    return envelope.header.eventId ?? SentryId.empty();
  }

  Future<SentryEvent> _eventFromEnvelope(SentryEnvelope envelope) async {
    final envelopeItemData = <int>[];
    envelopeItemData.addAll(await envelope.items.first.envelopeItemStream());

    final envelopeItem = utf8.decode(envelopeItemData).split('\n').last;
    final envelopeItemJson = jsonDecode(envelopeItem) as Map<String, dynamic>;
    return SentryEvent.fromJson(envelopeItemJson);
  }

  void reset() {
    envelopes.clear();
    events.clear();
    _calls = 0;
  }
}

class ThrowingTransport implements Transport {
  @override
  Future<SentryId> send(SentryEnvelope envelope) async {
    throw Exception('foo bar');
  }
}
