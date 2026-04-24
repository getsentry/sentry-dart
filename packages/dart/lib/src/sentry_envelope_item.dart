import 'dart:async';

import 'client_reports/client_report.dart';
import 'protocol.dart';
import 'sentry_attachment/sentry_attachment.dart';
import 'sentry_envelope_item_header.dart';
import 'sentry_item_type.dart';
import 'utils.dart';
import 'package:meta/meta.dart';

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

  factory SentryEnvelopeItem.fromLogs(List<SentryLog> items) {
    final payload = {
      'items': items.map((e) => e.toJson()).toList(),
    };
    return SentryEnvelopeItem(
      SentryEnvelopeItemHeader(
        SentryItemType.log,
        itemCount: items.length,
        contentType: 'application/vnd.sentry.items.log+json',
      ),
      () => utf8JsonEncoder.convert(payload),
      originalObject: payload,
    );
  }

  /// Create a [SentryEnvelopeItem] which holds pre-encoded log data.
  /// This is used by the log batcher to send pre-encoded log batches.
  @internal
  factory SentryEnvelopeItem.fromLogsData(List<int> payload, int logsCount) {
    return SentryEnvelopeItem(
      SentryEnvelopeItemHeader(
        SentryItemType.log,
        itemCount: logsCount,
        contentType: 'application/vnd.sentry.items.log+json',
      ),
      () => payload,
      originalObject: null,
    );
  }

  /// Create a [SentryEnvelopeItem] which holds pre-encoded span data.
  /// This is used by the spans buffer to send pre-encoded spans.
  @internal
  factory SentryEnvelopeItem.fromSpansData(List<int> payload, int spansCount) {
    return SentryEnvelopeItem(
      SentryEnvelopeItemHeader(
        SentryItemType.span,
        itemCount: spansCount,
        contentType: 'application/vnd.sentry.items.span.v2+json',
      ),
      () => payload,
      originalObject: null,
    );
  }

  /// Create a [SentryEnvelopeItem] which holds pre-encoded metric data.
  /// This is used by the buffer to send pre-encoded metric batches.
  @internal
  factory SentryEnvelopeItem.fromMetricsData(
      List<int> payload, int metricsCount) {
    return SentryEnvelopeItem(
      SentryEnvelopeItemHeader(
        SentryItemType.metric,
        itemCount: metricsCount,
        contentType: 'application/vnd.sentry.items.trace-metric+json',
      ),
      () => payload,
      originalObject: null,
    );
  }

  /// Header with info about type and length of data in bytes.
  final SentryEnvelopeItemHeader header;

  /// Create binary data representation of item data.
  final FutureOr<List<int>> Function() dataFactory;
}
