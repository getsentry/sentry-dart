import 'package:collection/collection.dart';
import 'package:sentry/src/client_reports/client_report.dart';
import 'package:sentry/src/client_reports/discard_reason.dart';
import 'package:sentry/src/client_reports/discarded_event.dart';
import 'package:sentry/src/transport/data_category.dart';
import 'package:test/test.dart';
import 'package:sentry/src/utils.dart';

void main() {
  group('json', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
    });

    test('toJson', () {
      final sut = fixture.getSut();
      final json = sut.toJson();

      expect(
        DeepCollectionEquality().equals(fixture.clientReportJson, json),
        true,
      );
    });
  });
}

class Fixture {
  final timestamp = DateTime.fromMillisecondsSinceEpoch(0);
  late Map<String, dynamic> clientReportJson;

  Fixture() {
    clientReportJson = <String, dynamic>{
      'timestamp': formatDateAsIso8601WithMillisPrecision(timestamp),
      'discarded_events': [
        {
          'reason': 'ratelimit_backoff',
          'category': 'error',
          'quantity': 2,
        }
      ],
    };
  }

  ClientReport getSut() {
    return ClientReport(
      timestamp,
      [
        DiscardedEvent(DiscardReason.rateLimitBackoff, DataCategory.error, 2),
      ],
    );
  }
}
