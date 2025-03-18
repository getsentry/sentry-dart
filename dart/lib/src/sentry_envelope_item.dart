import 'dart:async';

import 'client_reports/client_report.dart';
import 'protocol.dart';
import 'sentry_attachment/sentry_attachment.dart';
import 'sentry_envelope_item_header.dart';
import 'sentry_item_type.dart';
import 'utils.dart';

/// Item holding header information and JSON encoded data.
class SentryEnvelopeItem {
  /// The original, non-encoded object, used when direct access to the source data is needed.
  Object? originalObject;

  SentryEnvelopeItem(this.header, this.dataFactory, {this.originalObject});

  /// Creates a [SentryEnvelopeItem] which sends [SentryTransaction].
  factory SentryEnvelopeItem.fromTransaction(SentryTransaction transaction) {
    final header = SentryEnvelopeItemHeader(
      SentryItemType.transaction,
      contentType: 'application/json',
    );
    return SentryEnvelopeItem(
        header, () => utf8JsonEncoder.convert(transaction.toJson()),
        originalObject: transaction);
  }

  factory SentryEnvelopeItem.fromAttachment(SentryAttachment attachment) {
    final header = SentryEnvelopeItemHeader(
      SentryItemType.attachment,
      contentType: attachment.contentType,
      fileName: attachment.filename,
      attachmentType: attachment.attachmentType,
    );
    return SentryEnvelopeItem(
      header,
      () => attachment.bytes,
      originalObject: attachment,
    );
  }

  /// Create a [SentryEnvelopeItem] which holds the [SentryEvent] data.
  factory SentryEnvelopeItem.fromEvent(SentryEvent event) {
    return SentryEnvelopeItem(
      SentryEnvelopeItemHeader(
        event.type == 'feedback' ? 'feedback' : SentryItemType.event,
        contentType: 'application/json',
      ),
      () => utf8JsonEncoder.convert(event.toJson()),
      originalObject: event,
    );
  }

  /// Create a [SentryEnvelopeItem] which holds the [ClientReport] data.
  factory SentryEnvelopeItem.fromClientReport(ClientReport clientReport) {
    return SentryEnvelopeItem(
      SentryEnvelopeItemHeader(
        SentryItemType.clientReport,
        contentType: 'application/json',
      ),
      () => utf8JsonEncoder.convert(clientReport.toJson()),
      originalObject: clientReport,
    );
  }

  /// Header with info about type and length of data in bytes.
  final SentryEnvelopeItemHeader header;

  /// Create binary data representation of item data.
  final FutureOr<List<int>> Function() dataFactory;
}
