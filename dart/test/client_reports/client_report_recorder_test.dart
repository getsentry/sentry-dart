import 'package:sentry/src/client_reports/outcome.dart';
import 'package:sentry/src/transport/rate_limit_category.dart';
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

      sut.recordLostEvent(Outcome.ratelimitBackoff, RateLimitCategory.error);

      final clientReport = sut.flush();

      expect(clientReport?.timestamp, DateTime(0));
    });

    test('record lost event', () {
      final sut = fixture.getSut();

      sut.recordLostEvent(Outcome.ratelimitBackoff, RateLimitCategory.error);
      sut.recordLostEvent(Outcome.ratelimitBackoff, RateLimitCategory.error);

      final clientReport = sut.flush();

      final event = clientReport?.discardedEvents
          .firstWhere((element) => element.category == RateLimitCategory.error);

      expect(event?.reason, Outcome.ratelimitBackoff);
      expect(event?.category, RateLimitCategory.error);
      expect(event?.quantity, 2);
    });

    test('record outcomes with different categories recorded separately', () {
      final sut = fixture.getSut();

      sut.recordLostEvent(Outcome.ratelimitBackoff, RateLimitCategory.error);
      sut.recordLostEvent(
          Outcome.ratelimitBackoff, RateLimitCategory.transaction);

      final clientReport = sut.flush();

      final first = clientReport?.discardedEvents
          .firstWhere((event) => event.category == RateLimitCategory.error);

      final second = clientReport?.discardedEvents.firstWhere(
          (event) => event.category == RateLimitCategory.transaction);

      expect(first?.reason, Outcome.ratelimitBackoff);
      expect(first?.category, RateLimitCategory.error);
      expect(first?.quantity, 1);

      expect(second?.reason, Outcome.ratelimitBackoff);
      expect(second?.category, RateLimitCategory.transaction);
      expect(second?.quantity, 1);
    });

    test('calling flush multiple times returns null', () {
      final sut = fixture.getSut();

      sut.recordLostEvent(Outcome.ratelimitBackoff, RateLimitCategory.error);

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
