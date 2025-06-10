import 'dart:convert';

import 'package:sentry/sentry.dart';
import 'package:test/expect.dart';

class MockTransport implements Transport {
  List<SentryEnvelope> envelopes = [];
  List<SentryEvent> events = [];
  List<String> statsdItems = [];
  List<Map<String, dynamic>> logs = [];

  int _calls = 0;
  String _exceptions = '';

  int get calls {
    expect(_exceptions, isEmpty);
    return _calls;
  }

  bool parseFromEnvelope = true;

  bool called(int calls) {
    return _calls == calls;
  }

  @override
  Future<SentryId> send(SentryEnvelope envelope) async {
    _calls++;

    // Exception here would be swallowed by Sentry, making it hard to find test
    // failure causes. Instead, we log them and check on access to [calls].
    try {
      envelopes.add(envelope);
      if (parseFromEnvelope) {
        await _parseEnvelope(envelope);
      }
    } catch (e, stack) {
      _exceptions += '$e\n$stack\n\n';
      rethrow;
    }

    return envelope.header.eventId ?? SentryId.empty();
  }

  Future<void> _parseEnvelope(SentryEnvelope envelope) async {
    final RegExp statSdRegex = RegExp('^(?!{).+@.+:.+\\|.+', multiLine: true);

    final envelopeItemData = await envelope.items.first.dataFactory();
    final envelopeItem = utf8.decode(envelopeItemData);

    if (statSdRegex.hasMatch(envelopeItem)) {
      statsdItems.add(envelopeItem);
    } else if (envelopeItem.contains('items') &&
        envelopeItem.contains('timestamp') &&
        envelopeItem.contains('trace_id') &&
        envelopeItem.contains('level') &&
        envelopeItem.contains('body')) {
      final envelopeItemJson = jsonDecode(envelopeItem) as Map<String, dynamic>;
      logs.add(envelopeItemJson);
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
