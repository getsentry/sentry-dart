import 'package:sentry/src/client_reports/outcome.dart';
import 'package:sentry/src/transport/data_category.dart';
import 'package:test/test.dart';

import 'package:sentry/src/client_reports/client_report_recorder.dart';

void main() {
  group(ClientReportRecorder, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('flush returns null when there was nothing recorded', () {
      final sut = fixture.getSut();

      final clientReport = sut.flush();

      expect(clientReport, null);
    });

    test('flush returns client report with current date', () {
      final sut = fixture.getSut();

      sut.recordLostEvent(DiscardReason.ratelimitBackoff, DataCategory.error);

      final clientReport = sut.flush();

      expect(clientReport?.timestamp, DateTime(0));
    });

    test('record lost event', () {
      final sut = fixture.getSut();

      sut.recordLostEvent(DiscardReason.ratelimitBackoff, DataCategory.error);
      sut.recordLostEvent(DiscardReason.ratelimitBackoff, DataCategory.error);

      final clientReport = sut.flush();

      final event = clientReport?.discardedEvents
          .firstWhere((element) => element.category == DataCategory.error);

      expect(event?.reason, DiscardReason.ratelimitBackoff);
      expect(event?.category, DataCategory.error);
      expect(event?.quantity, 2);
    });

    test('record outcomes with different categories recorded separately', () {
      final sut = fixture.getSut();

      sut.recordLostEvent(DiscardReason.ratelimitBackoff, DataCategory.error);
      sut.recordLostEvent(
          DiscardReason.ratelimitBackoff, DataCategory.transaction);

      final clientReport = sut.flush();

      final first = clientReport?.discardedEvents
          .firstWhere((event) => event.category == DataCategory.error);

      final second = clientReport?.discardedEvents
          .firstWhere((event) => event.category == DataCategory.transaction);

      expect(first?.reason, DiscardReason.ratelimitBackoff);
      expect(first?.category, DataCategory.error);
      expect(first?.quantity, 1);

      expect(second?.reason, DiscardReason.ratelimitBackoff);
      expect(second?.category, DataCategory.transaction);
      expect(second?.quantity, 1);
    });

    test('calling flush multiple times returns null', () {
      final sut = fixture.getSut();

      sut.recordLostEvent(DiscardReason.ratelimitBackoff, DataCategory.error);

      sut.flush();
      final clientReport = sut.flush();

      expect(clientReport, null);
    });
  });
}

class Fixture {
  final _dateTimeProvider = () {
    return DateTime(0);
  };

  ClientReportRecorder getSut() {
    return ClientReportRecorder(_dateTimeProvider);
  }
}
