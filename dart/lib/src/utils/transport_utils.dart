import 'package:http/http.dart';

import '../client_reports/discard_reason.dart';
import '../protocol.dart';
import '../sentry_envelope.dart';
import '../sentry_options.dart';
import '../transport/data_category.dart';

class TransportUtils {
  static void logResponse(
      SentryOptions options, SentryEnvelope envelope, Response response,
      {required String target}) {
    if (response.statusCode != 200) {
      if (options.debug) {
        options.logger(
          SentryLevel.error,
          'Error, statusCode = ${response.statusCode}, body = ${response.body}',
        );
      }

      if (response.statusCode >= 400 && response.statusCode != 429) {
        for (final item in envelope.items) {
          options.recorder.recordLostEvent(
            DiscardReason.networkError,
            DataCategory.fromItemType(item.header.type),
          );

          final originalObject = item.originalObject;
          if (originalObject is SentryTransaction) {
            options.recorder.recordLostEvent(
              DiscardReason.networkError,
              DataCategory.span,
              count: originalObject.spans.length + 1,
            );
          }
        }
      }
    } else {
      options.logger(
        SentryLevel.debug,
        'Envelope ${envelope.header.eventId ?? "--"} was sent successfully to $target.',
      );
    }
  }
}
