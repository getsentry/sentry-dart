import 'dart:convert';

import 'sentry_envelope_header.dart';
import 'sentry_envelope_item.dart';
import 'protocol/sentry_event.dart';
import 'protocol/sdk_version.dart';

/// Class representation of `Envelope` file.
class SentryEnvelope {
  SentryEnvelope(this.header, this.items);

  /// Header descriping envelope content.
  final SentryEnvelopeHeader header;

  /// All items contained in the envelope.
  final List<SentryEnvelopeItem> items;

  /// Create an `SentryEnvelope` with containing one `SentryEnvelopeItem` which holds the `SentyEvent` data.
  factory SentryEnvelope.fromEvent(SentryEvent event, SdkVersion sdkVersion) {
    return SentryEnvelope(SentryEnvelopeHeader(event.eventId, sdkVersion),
        [SentryEnvelopeItem.fromEvent(event)]);
  }

  /// Create binary data representation of `Envelope` file encoded in utf8.
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
