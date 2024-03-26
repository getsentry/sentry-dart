import 'dart:async';
import 'dart:convert';

import 'client_reports/client_report.dart';
import 'metrics/metric.dart';
import 'protocol.dart';
import 'utils.dart';
import 'sentry_attachment/sentry_attachment.dart';
import 'sentry_item_type.dart';
import 'sentry_envelope_item_header.dart';
import 'sentry_user_feedback.dart';

/// Item holding header information and JSON encoded data.
class SentryEnvelopeItem {
  SentryEnvelopeItem(this.header, this.dataFactory);

  /// Creates a [SentryEnvelopeItem] which sends [SentryTransaction].
  factory SentryEnvelopeItem.fromTransaction(SentryTransaction transaction) {
    final cachedItem =
        _CachedItem(() async => utf8JsonEncoder.convert(transaction.toJson()));

    final header = SentryEnvelopeItemHeader(
      SentryItemType.transaction,
      cachedItem.getDataLength,
      contentType: 'application/json',
    );
    return SentryEnvelopeItem(header, cachedItem.getData);
  }

  factory SentryEnvelopeItem.fromAttachment(SentryAttachment attachment) {
    final cachedItem = _CachedItem(() async => attachment.bytes);

    final header = SentryEnvelopeItemHeader(
      SentryItemType.attachment,
      cachedItem.getDataLength,
      contentType: attachment.contentType,
      fileName: attachment.filename,
      attachmentType: attachment.attachmentType,
    );
    return SentryEnvelopeItem(header, cachedItem.getData);
  }

  /// Create a [SentryEnvelopeItem] which sends [SentryUserFeedback].
  factory SentryEnvelopeItem.fromUserFeedback(SentryUserFeedback feedback) {
    final cachedItem =
        _CachedItem(() async => utf8JsonEncoder.convert(feedback.toJson()));

    final header = SentryEnvelopeItemHeader(
      SentryItemType.userFeedback,
      cachedItem.getDataLength,
      contentType: 'application/json',
    );
    return SentryEnvelopeItem(header, cachedItem.getData);
  }

  /// Create a [SentryEnvelopeItem] which holds the [SentryEvent] data.
  factory SentryEnvelopeItem.fromEvent(SentryEvent event) {
    final cachedItem =
        _CachedItem(() async => utf8JsonEncoder.convert(event.toJson()));

    return SentryEnvelopeItem(
      SentryEnvelopeItemHeader(
        SentryItemType.event,
        cachedItem.getDataLength,
        contentType: 'application/json',
      ),
      cachedItem.getData,
    );
  }

  /// Create a [SentryEnvelopeItem] which holds the [ClientReport] data.
  factory SentryEnvelopeItem.fromClientReport(ClientReport clientReport) {
    final cachedItem =
        _CachedItem(() async => utf8JsonEncoder.convert(clientReport.toJson()));

    return SentryEnvelopeItem(
      SentryEnvelopeItemHeader(
        SentryItemType.clientReport,
        cachedItem.getDataLength,
        contentType: 'application/json',
      ),
      cachedItem.getData,
    );
  }

  /// Creates a [SentryEnvelopeItem] which holds several [Metric] data.
  factory SentryEnvelopeItem.fromMetrics(Map<int, Iterable<Metric>> buckets) {
    final cachedItem = _CachedItem(() async {
      final statsd = StringBuffer();
      // Encode all metrics of a bucket in statsd format, using the bucket key,
      //  which is the timestamp of the bucket.
      for (final bucket in buckets.entries) {
        final encodedMetrics =
            bucket.value.map((metric) => metric.encodeToStatsd(bucket.key));
        statsd.write(encodedMetrics.join('\n'));
      }
      return utf8.encode(statsd.toString());
    });

    final header = SentryEnvelopeItemHeader(
      SentryItemType.statsd,
      cachedItem.getDataLength,
      contentType: 'application/octet-stream',
    );
    return SentryEnvelopeItem(header, cachedItem.getData);
  }

  /// Header with info about type and length of data in bytes.
  final SentryEnvelopeItemHeader header;

  /// Create binary data representation of item data.
  final Future<List<int>> Function() dataFactory;

  /// Stream binary data of `Envelope` item.
  Future<List<int>> envelopeItemStream() async {
    // Each item needs to be encoded as one unit.
    // Otherwise the header already got yielded if the content throws
    // an exception.
    try {
      final itemHeader = utf8JsonEncoder.convert(await header.toJson());

      final newLine = utf8.encode('\n');
      final data = await dataFactory();
      // TODO the data copy could be avoided - this would be most significant with attachments.
      return [...itemHeader, ...newLine, ...data];
    } catch (e) {
      return [];
    }
  }
}

class _CachedItem {
  _CachedItem(this._dataFactory);

  final Future<List<int>> Function() _dataFactory;
  List<int>? _data;

  Future<List<int>> getData() async {
    _data ??= await _dataFactory();
    return _data!;
  }

  Future<int> getDataLength() async {
    try {
      return (await getData()).length;
    } catch (_) {
      return -1;
    }
  }
}
