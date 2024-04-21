import 'dart:convert';

import 'package:sentry/sentry.dart';
import 'package:test/expect.dart';

class MockTransport implements Transport {
  List<SentryEnvelope> envelopes = [];
  List<SentryEvent> events = [];
  List<String> statsdItems = [];

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
      await _eventFromEnvelope(envelope);
    } catch (e, stack) {
      _exceptions += '$e\n$stack\n\n';
      rethrow;
    }

    return envelope.header.eventId ?? SentryId.empty();
  }

  Future<void> _eventFromEnvelope(SentryEnvelope envelope) async {
    final envelopeItemData = <int>[];
    final RegExp statSdRegex = RegExp('^(?!{).+@.+:.+\\|.+', multiLine: true);
    envelopeItemData.addAll(await envelope.items.first.envelopeItemStream());

    final envelopeItem = utf8.decode(envelopeItemData).split('\n').last;
    if (statSdRegex.hasMatch(envelopeItem)) {
      statsdItems.add(envelopeItem);
    } else {
      final envelopeItemJson = jsonDecode(envelopeItem) as Map<String, dynamic>;
      events.add(SentryEvent.fromJson(envelopeItemJson));
    }
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
