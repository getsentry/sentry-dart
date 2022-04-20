import 'dart:convert';
import 'protocol.dart';
import 'sentry_item_type.dart';
import 'sentry_options.dart';
import 'utils.dart';
import 'sentry_attachment/sentry_attachment.dart';
import 'sentry_envelope_header.dart';
import 'sentry_envelope_item.dart';
import 'sentry_user_feedback.dart';

/// Class representation of `Envelope` file.
class SentryEnvelope {
  SentryEnvelope(this.header, this.items);

  /// Header descriping envelope content.
  final SentryEnvelopeHeader header;

  /// All items contained in the envelope.
  final List<SentryEnvelopeItem> items;

  /// Create an [SentryEnvelope] with containing one [SentryEnvelopeItem] which holds the [SentryEvent] data.
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

  factory SentryEnvelope.fromUserFeedback(
    SentryUserFeedback feedback,
    SdkVersion sdkVersion,
  ) {
    return SentryEnvelope(
      SentryEnvelopeHeader(feedback.eventId, sdkVersion),
      [SentryEnvelopeItem.fromUserFeedback(feedback)],
    );
  }

  /// Create an [SentryEnvelope] with containing one [SentryEnvelopeItem] which holds the [SentryTransaction] data.
  factory SentryEnvelope.fromTransaction(
    SentryTransaction transaction,
    SdkVersion sdkVersion, {
    List<SentryAttachment>? attachments,
  }) {
    return SentryEnvelope(
      SentryEnvelopeHeader(transaction.eventId, sdkVersion),
      [
        SentryEnvelopeItem.fromTransaction(transaction),
        if (attachments != null)
          ...attachments.map((e) => SentryEnvelopeItem.fromAttachment(e))
      ],
    );
  }

  /// Stream binary data representation of `Envelope` file encoded.
  Stream<List<int>> envelopeStream(SentryOptions options) async* {
    yield utf8.encode(jsonEncode(
      header.toJson(),
      toEncodable: jsonSerializationFallback,
    ));
    final newLineData = utf8.encode('\n');
    for (final item in items) {
      final length = await item.header.length();
      // A length smaller than 0 indicates an invalid envelope, which should not
      // be send to Sentry.io
      if (length < 0) {
        continue;
      }
      // Olny attachments should be filtered according to
      // SentryOptions.maxAttachmentSize
      if (item.header.type == SentryItemType.attachment) {
        if (await item.header.length() > options.maxAttachmentSize) {
          continue;
        }
      }
      final itemStream = await item.envelopeItemStream();
      if (itemStream.isNotEmpty) {
        yield newLineData;
        yield itemStream;
      }
    }
  }
}
