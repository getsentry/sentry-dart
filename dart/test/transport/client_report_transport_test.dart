import 'package:sentry/sentry.dart';
import 'package:sentry/src/client_reports/client_report.dart';
import 'package:sentry/src/client_reports/discard_reason.dart';
import 'package:sentry/src/client_reports/discarded_event.dart';
import 'package:sentry/src/sentry_item_type.dart';
import 'package:sentry/src/transport/client_report_transport.dart';
import 'package:sentry/src/transport/data_category.dart';
import 'package:sentry/src/transport/rate_limiter.dart';
import 'package:test/test.dart';

import '../mocks.dart';
import '../mocks/mock_client_report_recorder.dart';
import '../mocks/mock_envelope.dart';
import '../mocks/mock_transport.dart';
import '../test_utils.dart';

void main() {
  group('filter', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('filter called', () async {
      final mockRateLimiter = MockRateLimiter();
      final sut = fixture.getSut(rateLimiter: mockRateLimiter);

      final envelope = MockEnvelope();
      await sut.send(envelope);

      expect(mockRateLimiter.envelopeToFilter, envelope);
      expect(fixture.mockTransport.envelopes.first, envelope);
    });

    test('send nothing when filtered event null', () async {
      final mockRateLimiter = MockRateLimiter()..filterReturnsNull = true;
      final sut = fixture.getSut(rateLimiter: mockRateLimiter);

      final envelope = MockEnvelope();
      final eventId = await sut.send(envelope);

      expect(eventId, SentryId.empty());
      expect(fixture.mockTransport.called(0), true);
    });
  });

  group('client reports', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('send calls flush', () async {
      final sut = fixture.getSut();

      final envelope = MockEnvelope();
      envelope.items = [SentryEnvelopeItem.fromEvent(SentryEvent())];

      await sut.send(envelope);

      expect(fixture.recorder.flushCalled, true);
    });

    test('send adds client report', () async {
      final clientReport = ClientReport(
        DateTime(0),
        [DiscardedEvent(DiscardReason.rateLimitBackoff, DataCategory.error, 1)],
      );
      fixture.recorder.clientReport = clientReport;

      final sut = fixture.getSut();

      final envelope = MockEnvelope();
      envelope.items = [SentryEnvelopeItem.fromEvent(SentryEvent())];

      await sut.send(envelope);

      expect(envelope.clientReport, clientReport);
    });
  });

  group('client report only event', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('send after filtering out 10 times and client report', () async {
      final clientReport = ClientReport(
        DateTime(0),
        [DiscardedEvent(DiscardReason.rateLimitBackoff, DataCategory.error, 1)],
      );
      fixture.recorder.clientReport = clientReport;

      final mockRateLimiter = MockRateLimiter()..filterReturnsNull = true;

      final sut = fixture.getSut(rateLimiter: mockRateLimiter);

      final envelope = MockEnvelope();
      envelope.items = [SentryEnvelopeItem.fromEvent(SentryEvent())];

      for (int i = 0; i < 10; i++) {
        await sut.send(envelope);
      }

      expect(fixture.mockTransport.called(1), true);

      final sentEnvelope = fixture.mockTransport.envelopes.first;
      expect(sentEnvelope.items.length, 1);
      expect(sentEnvelope.items[0].header.type, SentryItemType.clientReport);
    });

    test('filter out after 10 times with no client reports', () async {
      final mockRateLimiter = MockRateLimiter()..filterReturnsNull = true;

      final sut = fixture.getSut(rateLimiter: mockRateLimiter);

      final envelope = MockEnvelope();
      envelope.items = [SentryEnvelopeItem.fromEvent(SentryEvent())];

      for (int i = 0; i < 10; i++) {
        await sut.send(envelope);
      }

      expect(fixture.mockTransport.called(0), true);
    });

    test('reset counter', () async {
      final clientReport = ClientReport(
        DateTime(0),
        [DiscardedEvent(DiscardReason.rateLimitBackoff, DataCategory.error, 1)],
      );
      fixture.recorder.clientReport = clientReport;

      final mockRateLimiter = MockRateLimiter()..filterReturnsNull = true;

      final sut = fixture.getSut(rateLimiter: mockRateLimiter);

      final envelope = MockEnvelope();
      envelope.items = [SentryEnvelopeItem.fromEvent(SentryEvent())];

      for (int i = 0; i < 20; i++) {
        await sut.send(envelope);
      }

      expect(fixture.mockTransport.called(2), true);
    });
  });
}

class Fixture {
  final options = defaultTestOptions();

  late var recorder = MockClientReportRecorder();
  late var mockTransport = MockTransport();

  ClientReportTransport getSut({RateLimiter? rateLimiter}) {
    mockTransport.parseFromEnvelope = false;
    options.recorder = recorder;
    return ClientReportTransport(rateLimiter, options, mockTransport);
  }
}
