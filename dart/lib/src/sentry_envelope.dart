import 'dart:convert';
import 'sentry_attachment/sentry_attachment.dart';
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
  factory SentryEnvelope.fromEvent(
    SentryEvent event,
    SdkVersion sdkVersion, {
    List<SentryAttachment>? attachments,
  }) {
    return SentryEnvelope(
      SentryEnvelopeHeader(event.eventId, sdkVersion),
      [
        SentryEnvelopeItem.fromEvent(event),
        if (attachments != null)
          ...attachments.map((e) => SentryEnvelopeItem.fromAttachment(e))
      ],
    );
  }

  /// Stream binary data representation of `Envelope` file encoded.
  Stream<List<int>> envelopeStream() async* {
    yield utf8.encode(jsonEncode(header.toJson()));
    final newLineData = utf8.encode('\n');
    for (final item in items) {
      final itemStream = await item.envelopeItemStream();
      if (itemStream.isNotEmpty) {
        yield newLineData;
        yield itemStream;
      }
    }
  }
}
