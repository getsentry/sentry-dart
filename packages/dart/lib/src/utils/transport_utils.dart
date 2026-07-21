import 'package:http/http.dart';

import '../client_reports/discard_reason.dart';
import '../protocol.dart';
import '../sentry_envelope.dart';
import '../sentry_envelope_item.dart';
import '../sentry_options.dart';
import '../transport/data_category.dart';
import 'internal_logger.dart';

class TransportUtils {
  static void logResponse(SentryEnvelope envelope, Response response,
      {required String target}) {
    if (response.statusCode != 200) {
      internalLogger.error(() =>
          'Failed to send envelope, statusCode = ${response.statusCode}, body = ${response.body}');
    } else {
      internalLogger.debug(
        () =>
            'Envelope ${envelope.header.eventId ?? "--"} was sent successfully to $target.',
      );
    }
  }

  static void recordLostEvents(
      SentryOptions options, SentryEnvelope envelope, DiscardReason reason) {
    for (final item in envelope.items) {
      final category = DataCategory.fromItemType(item.header.type);
      if (category == DataCategory.logItem) {
        recordLostLogItem(options, item, reason);
      } else if (category == DataCategory.metric) {
        recordLostMetricItem(options, item, reason);
      } else {
        options.recorder.recordLostEvent(reason, category);
      }

      final originalObject = item.originalObject;
      if (originalObject is SentryTransaction) {
        options.recorder.recordLostEvent(
          reason,
          DataCategory.span,
          count: originalObject.spans.length + 1,
        );
      }
    }
  }

  /// Records a dropped log envelope item, reporting the log item count and,
  /// when it can be determined, a best-effort byte size.
  static void recordLostLogItem(
    SentryOptions options,
    SentryEnvelopeItem item,
    DiscardReason reason,
  ) {
    int? bytes;
    try {
      final data = item.dataFactory();
      if (data is List<int>) {
        bytes = data.length;
      }
    } catch (exception, stackTrace) {
      internalLogger.warning(
        'Failed to estimate dropped log item size',
        error: exception,
        stackTrace: stackTrace,
      );
    }

    options.recorder.recordLostLog(
      reason,
      count: item.header.itemCount ?? 1,
      bytes: bytes,
    );
  }

  /// Records a dropped metric envelope item, reporting the metric count and,
  /// when it can be determined, a best-effort byte size.
  static void recordLostMetricItem(
    SentryOptions options,
    SentryEnvelopeItem item,
    DiscardReason reason,
  ) {
    int? bytes;
    try {
      final data = item.dataFactory();
      if (data is List<int>) {
        bytes = data.length;
      }
    } catch (exception, stackTrace) {
      internalLogger.warning(
        'Failed to estimate dropped metric item size',
        error: exception,
        stackTrace: stackTrace,
      );
    }

    options.recorder.recordLostMetric(
      reason,
      count: item.header.itemCount ?? 1,
      bytes: bytes,
    );
  }
}
