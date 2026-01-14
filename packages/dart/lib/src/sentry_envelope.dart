import 'dart:convert';
import 'dart:typed_data';

import 'client_reports/client_report.dart';
import 'protocol.dart';
import 'sentry_attachment/sentry_attachment.dart';
import 'sentry_envelope_header.dart';
import 'sentry_envelope_item.dart';
import 'sentry_item_type.dart';
import 'sentry_options.dart';
import 'sentry_trace_context_header.dart';
import 'utils.dart';
import 'package:meta/meta.dart';

/// Class representation of `Envelope` file.
class SentryEnvelope {
  SentryEnvelope(this.header, this.items,
      {this.containsUnhandledException = false});

  /// Header describing envelope content.
  final SentryEnvelopeHeader header;

  /// All items contained in the envelope.
  final List<SentryEnvelopeItem> items;

  /// Whether the envelope contains an unhandled exception.
  /// This is used to determine if the native SDK should start a new session.
  final bool containsUnhandledException;

  /// Create a [SentryEnvelope] containing one [SentryEnvelopeItem] which holds the [SentryEvent] data.
  factory SentryEnvelope.fromEvent(
    SentryEvent event,
    SdkVersion sdkVersion, {
    String? dsn,
    SentryTraceContextHeader? traceContext,
    List<SentryAttachment>? attachments,
  }) {
    bool containsUnhandledException = false;

    if (event.exceptions != null && event.exceptions!.isNotEmpty) {
      // Check all exceptions for any unhandled ones
      containsUnhandledException = event.exceptions!.any((exception) {
        return exception.mechanism?.handled == false;
      });
    }

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
      containsUnhandledException: containsUnhandledException,
    );
  }

  /// Create a [SentryEnvelope] containing one [SentryEnvelopeItem] which holds the [SentryTransaction] data.
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

  factory SentryEnvelope.fromLogs(
    List<SentryLog> items,
    SdkVersion sdkVersion,
  ) {
    return SentryEnvelope(
      SentryEnvelopeHeader(
        null,
        sdkVersion,
      ),
      [
        SentryEnvelopeItem.fromLogs(items),
      ],
    );
  }

  /// Create a [SentryEnvelope] containing raw log data payload.
  /// This is used by the log batcher to send pre-encoded log batches.
  @internal
  factory SentryEnvelope.fromLogsData(
    List<List<int>> encodedLogs,
    SdkVersion sdkVersion,
  ) {
    // Create the payload in the format expected by Sentry
    // Format: {"items": [log1, log2, ...]}
    final builder = BytesBuilder(copy: false);
    builder.add(utf8.encode('{"items":['));
    for (int i = 0; i < encodedLogs.length; i++) {
      if (i > 0) {
        builder.add(utf8.encode(','));
      }
      builder.add(encodedLogs[i]);
    }
    builder.add(utf8.encode(']}'));

    return SentryEnvelope(
      SentryEnvelopeHeader(
        null,
        sdkVersion,
      ),
      [
        SentryEnvelopeItem.fromLogsData(
            builder.takeBytes(), encodedLogs.length),
      ],
    );
  }

  /// Create a [SentryEnvelope] containing raw metric data payload.
  /// This is used by the log batcher to send pre-encoded metric batches.
  @internal
  factory SentryEnvelope.fromMetricsData(
    List<List<int>> encodedMetrics,
    SdkVersion sdkVersion,
  ) =>
      SentryEnvelope(
        SentryEnvelopeHeader(null, sdkVersion),
        [
          SentryEnvelopeItem.fromMetricsData(
              _buildItemsPayload(encodedMetrics), encodedMetrics.length)
        ],
      );

  /// Stream binary data representation of `Envelope` file encoded.
  Stream<List<int>> envelopeStream(SentryOptions options) async* {
    yield utf8JsonEncoder.convert(header.toJson());

    final newLineData = utf8.encode('\n');
    for (final item in items) {
      try {
        final dataFuture = item.dataFactory();
        final data = dataFuture is Future ? await dataFuture : dataFuture;

        // Only attachments should be filtered according to
        // SentryOptions.maxAttachmentSize
        if (item.header.type == SentryItemType.attachment &&
            data.length > options.maxAttachmentSize) {
          continue;
        }

        yield newLineData;
        yield utf8JsonEncoder.convert(await item.header.toJson(data.length));
        yield newLineData;
        yield data;
      } catch (_) {
        if (options.automatedTestMode) {
          rethrow;
        }
        // Skip throwing envelope item data closure.
        continue;
      }
    }
  }

  /// Builds a payload in the format {"items": [item1, item2, ...]}
  static Uint8List _buildItemsPayload(List<List<int>> encodedItems) {
    final builder = BytesBuilder(copy: false);
    builder.add(utf8.encode('{"items":['));
    for (int i = 0; i < encodedItems.length; i++) {
      if (i > 0) {
        builder.add(utf8.encode(','));
      }
      builder.add(encodedItems[i]);
    }
    builder.add(utf8.encode(']}'));
    return builder.takeBytes();
  }

  /// Add an envelope item containing client report data.
  void addClientReport(ClientReport? clientReport) {
    if (clientReport != null) {
      final envelopeItem = SentryEnvelopeItem.fromClientReport(clientReport);
      items.add(envelopeItem);
    }
  }
}
