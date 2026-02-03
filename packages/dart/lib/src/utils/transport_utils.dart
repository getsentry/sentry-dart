import 'package:http/http.dart';

import '../client_reports/discard_reason.dart';
import '../protocol.dart';
import '../sentry_envelope.dart';
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
      options.recorder.recordLostEvent(
        reason,
        DataCategory.fromItemType(item.header.type),
      );

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
}
