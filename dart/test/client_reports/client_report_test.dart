import 'package:collection/collection.dart';
import 'package:sentry/src/client_reports/client_report.dart';
import 'package:sentry/src/client_reports/discarded_event.dart';
import 'package:sentry/src/client_reports/outcome.dart';
import 'package:sentry/src/transport/rate_limit_category.dart';
import 'package:test/test.dart';
import 'package:sentry/src/utils.dart';

void main() {
  group('json', () {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(0);

    final clientReport = ClientReport(
      timestamp,
      [
        DiscardedEvent(Outcome.ratelimitBackoff, RateLimitCategory.error, 2),
      ],
    );

    final clientReportJson = <String, dynamic>{
      'timestamp': formatDateAsIso8601WithMillisPrecision(timestamp),
      'discarded_events': [
        {
          'reason': 'ratelimit_backoff',
          'category': 'error',
          'quantity': 2,
        }
      ],
    };

    test('toJson', () {
      final json = clientReport.toJson();

      expect(
        DeepCollectionEquality().equals(clientReportJson, json),
        true,
      );
    });
  });
}
