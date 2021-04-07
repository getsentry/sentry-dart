import 'dart:convert';

import 'sentry_envelope_header.dart';
import 'sentry_envelope_item.dart';
import 'protocol/sentry_event.dart';
import 'protocol/sdk_version.dart';

class SentryEnvelope {
  SentryEnvelope(this.header, this.items);

  final SentryEnvelopeHeader header;
  final List<SentryEnvelopeItem> items;

  factory SentryEnvelope.fromEvent(SentryEvent event, SdkVersion sdkVersion) {
    return SentryEnvelope(SentryEnvelopeHeader(event.eventId, sdkVersion),
        [SentryEnvelopeItem.fromEvent(event)]);
  }

  Future<List<int>> toEnvelope() async {
    var data = <int>[];
    data.addAll(utf8.encode(jsonEncode(header.toJson())));
    final newLineData = utf8.encode('\n');
    for (final item in items) {
      data.addAll(newLineData);
      data.addAll(await item.toEnvelopeItem());
    }
    return data;
  }
}
