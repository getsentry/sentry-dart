import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentry/src/client_reports/discarded_event.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:sentry/src/sentry_envelope_item_header.dart';
import 'package:sentry/src/sentry_item_type.dart';
import 'package:sentry/src/transport/rate_limiter.dart';
import 'package:test/test.dart';
import 'package:sentry/src/sentry_tracer.dart';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/transport/http_transport.dart';

import '../mocks.dart';
import '../mocks/mock_client_report_recorder.dart';
import '../mocks/mock_envelope.dart';
import '../mocks/mock_hub.dart';

void main() {
  SentryEnvelope givenEnvelope() {
    final filteredEnvelopeHeader = SentryEnvelopeHeader(SentryId.empty(), null);
    final filteredItemHeader =
        SentryEnvelopeItemHeader(SentryItemType.event, () async {
      return 2;
    }, contentType: 'application/json');
    final dataFactory = () async {
      return utf8.encode('{}');
    };
    final filteredItem = SentryEnvelopeItem(filteredItemHeader, dataFactory);
    return SentryEnvelope(filteredEnvelopeHeader, [filteredItem]);
  }

  group('filter', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('filter called', () async {
      final httpMock = MockClient((http.Request request) async {
        return http.Response('{}', 200);
      });

      fixture.options.compressPayload = false;
      final mockRateLimiter = MockRateLimiter();
      final sut = fixture.getSut(httpMock, mockRateLimiter);

      final sentryEnvelope = givenEnvelope();
      await sut.send(sentryEnvelope);

      expect(mockRateLimiter.envelopeToFilter, sentryEnvelope);
    });

    test('send filtered event', () async {
      List<int>? body;

      final httpMock = MockClient((http.Request request) async {
        body = request.bodyBytes;
        return http.Response('{}', 200);
      });

      final filteredEnvelope = givenEnvelope();

      fixture.options.compressPayload = false;
      final mockRateLimiter = MockRateLimiter()
        ..filteredEnvelope = filteredEnvelope;
      final sut = fixture.getSut(httpMock, mockRateLimiter);

      final sentryEvent = SentryEvent();
      final envelope =
          SentryEnvelope.fromEvent(sentryEvent, fixture.options.sdk);
      await sut.send(envelope);

      final envelopeData = <int>[];
      await filteredEnvelope
          .envelopeStream(fixture.options)
          .forEach(envelopeData.addAll);

      expect(body, envelopeData);
    });

    test('send nothing when filtered event null', () async {
      var httpCalled = false;
      final httpMock = MockClient((http.Request request) async {
        httpCalled = true;
        return http.Response('{}', 200);
      });

      fixture.options.compressPayload = false;
      final mockRateLimiter = MockRateLimiter()..filterReturnsNull = true;
      final sut = fixture.getSut(httpMock, mockRateLimiter);

      final sentryEvent = SentryEvent();
      final envelope =
          SentryEnvelope.fromEvent(sentryEvent, fixture.options.sdk);
      final eventId = await sut.send(envelope);

      expect(eventId, SentryId.empty());
      expect(httpCalled, false);
    });
  });

  group('updateRetryAfterLimits', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('retryAfterHeader', () async {
      final httpMock = MockClient((http.Request request) async {
        return http.Response('{}', 429, headers: {'Retry-After': '1'});
      });
      final mockRateLimiter = MockRateLimiter();
      final sut = fixture.getSut(httpMock, mockRateLimiter);

      final sentryEvent = SentryEvent();
      final envelope =
          SentryEnvelope.fromEvent(sentryEvent, fixture.options.sdk);
      await sut.send(envelope);

      expect(mockRateLimiter.envelopeToFilter?.header.eventId,
          sentryEvent.eventId);

      expect(mockRateLimiter.errorCode, 429);
      expect(mockRateLimiter.retryAfterHeader, '1');
      expect(mockRateLimiter.sentryRateLimitHeader, isNull);
    });

    test('sentryRateLimitHeader', () async {
      final httpMock = MockClient((http.Request request) async {
        return http.Response('{}', 200,
            headers: {'X-Sentry-Rate-Limits': 'fixture-sentryRateLimitHeader'});
      });
      final mockRateLimiter = MockRateLimiter();
      final sut = fixture.getSut(httpMock, mockRateLimiter);

      final sentryEvent = SentryEvent();
      final envelope =
          SentryEnvelope.fromEvent(sentryEvent, fixture.options.sdk);
      await sut.send(envelope);

      expect(mockRateLimiter.errorCode, 200);
      expect(mockRateLimiter.retryAfterHeader, isNull);
      expect(mockRateLimiter.sentryRateLimitHeader,
          'fixture-sentryRateLimitHeader');
    });
  });

  group('client reports', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('flush called', () async {
      final mockClient = MockClient((http.Request request) async {
        return http.Response('{}', 200);
      });
      final mockRateLimiter = MockRateLimiter();

      final sut = fixture.getSut(mockClient, mockRateLimiter);
      final sentryEvent = SentryEvent();
      final envelope = SentryEnvelope.fromEvent(
        sentryEvent,
        fixture.options.sdk,
      );

      await sut.send(envelope);

      expect(fixture.clientReportRecorder.flushCalled, true);
    });

    test('client report added to envelope', () async {
      final mockClient = MockClient((http.Request request) async {
        return http.Response('{}', 200);
      });
      final mockRateLimiter = MockRateLimiter();

      final clientReport = ClientReport(
        DateTime(0),
        [DiscardedEvent(DiscardReason.rateLimitBackoff, DataCategory.error, 1)],
      );

      fixture.clientReportRecorder.clientReport = clientReport;

      final sut = fixture.getSut(mockClient, mockRateLimiter);
      final mockEnvelope = MockEnvelope();

      await sut.send(mockEnvelope);

      expect(clientReport, mockEnvelope.clientReport);
    });
  });
}

class Fixture {
  final options = SentryOptions(
    dsn: 'https://public:secret@sentry.example.com/1',
  );

  late var clientReportRecorder = MockClientReportRecorder();

  HttpTransport getSut(http.Client client, RateLimiter rateLimiter) {
    options.httpClient = client;
    return HttpTransport(options, rateLimiter, clientReportRecorder);
  }

  SentryTracer createTracer({
    bool? sampled,
  }) {
    final context = SentryTransactionContext(
      'name',
      'op',
      sampled: sampled,
    );
    return SentryTracer(context, MockHub());
  }
}
