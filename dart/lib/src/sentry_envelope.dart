import 'dart:convert';
import 'client_reports/client_report.dart';
import 'protocol.dart';
import 'sentry_item_type.dart';
import 'sentry_options.dart';
import 'sentry_trace_context_header.dart';
import 'utils.dart';
import 'sentry_attachment/sentry_attachment.dart';
import 'sentry_envelope_header.dart';
import 'sentry_envelope_item.dart';
import 'sentry_user_feedback.dart';

/// Class representation of `Envelope` file.
class SentryEnvelope {
  SentryEnvelope(this.header, this.items);

  /// Header describing envelope content.
  final SentryEnvelopeHeader header;

  /// All items contained in the envelope.
  final List<SentryEnvelopeItem> items;

  /// Create an [SentryEnvelope] with containing one [SentryEnvelopeItem] which holds the [SentryEvent] data.
  factory SentryEnvelope.fromEvent(
    SentryEvent event,
    SdkVersion sdkVersion, {
    String? dsn,
    SentryTraceContextHeader? traceContext,
    List<SentryAttachment>? attachments,
  }) {
    return SentryEnvelope(
      SentryEnvelopeHeader(
        event.eventId,
        sdkVersion,
        dsn: dsn,
        traceContext: traceContext,
      ),
      [
        SentryEnvelopeItem.fromEvent(event),
        if (attachments != null)
          ...attachments.map((e) => SentryEnvelopeItem.fromAttachment(e))
      ],
    );
  }

  factory SentryEnvelope.fromUserFeedback(
    SentryUserFeedback feedback,
    SdkVersion sdkVersion, {
    String? dsn,
  }) {
    return SentryEnvelope(
      // no need for [traceContext]
      SentryEnvelopeHeader(
        feedback.eventId,
        sdkVersion,
        dsn: dsn,
      ),
      [SentryEnvelopeItem.fromUserFeedback(feedback)],
    );
  }

  /// Create an [SentryEnvelope] with containing one [SentryEnvelopeItem] which holds the [SentryTransaction] data.
  factory SentryEnvelope.fromTransaction(
    SentryTransaction transaction,
    SdkVersion sdkVersion, {
    String? dsn,
    SentryTraceContextHeader? traceContext,
    List<SentryAttachment>? attachments,
  }) {
    return SentryEnvelope(
      SentryEnvelopeHeader(
        transaction.eventId,
        sdkVersion,
        dsn: dsn,
        traceContext: traceContext,
      ),
      [
        SentryEnvelopeItem.fromTransaction(transaction),
        if (attachments != null)
          ...attachments.map((e) => SentryEnvelopeItem.fromAttachment(e))
      ],
    );
  }

  /// Stream binary data representation of `Envelope` file encoded.
  Stream<List<int>> envelopeStream(SentryOptions options) async* {
    yield utf8JsonEncoder.convert(header.toJson());

    final newLineData = utf8.encode('\n');
    for (final item in items) {
      final length = await item.header.length();
      // A length smaller than 0 indicates an invalid envelope, which should not
      // be send to Sentry.io
      if (length < 0) {
        continue;
      }
      // Only attachments should be filtered according to
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

  /// Add an envelope item containing client report data.
  void addClientReport(ClientReport? clientReport) {
    if (clientReport != null) {
      final envelopeItem = SentryEnvelopeItem.fromClientReport(clientReport);
      items.add(envelopeItem);
    }
  }
}
