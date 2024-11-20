import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/client_reports/discard_reason.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry/src/transport/data_category.dart';
import 'package:sentry/src/transport/http_transport.dart';
import 'package:sentry/src/transport/rate_limiter.dart';
import 'package:test/test.dart';

import '../mocks.dart';
import '../mocks/mock_client_report_recorder.dart';
import '../mocks/mock_hub.dart';
import '../test_utils.dart';

void main() {
  group('send', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('event with http client', () async {
      List<int>? body;

      final httpMock = MockClient((http.Request request) async {
        body = request.bodyBytes;
        return http.Response('{}', 200);
      });

      fixture.options.compressPayload = false;
      final mockRateLimiter = MockRateLimiter();

      final sut = fixture.getSut(httpMock, mockRateLimiter);

      final sentryEvent = SentryEvent();
      final envelope = SentryEnvelope.fromEvent(
        sentryEvent,
        fixture.options.sdk,
        dsn: fixture.options.dsn,
      );
      await sut.send(envelope);

      final envelopeData = <int>[];
      await envelope
          .envelopeStream(fixture.options)
          .forEach(envelopeData.addAll);

      expect(body, envelopeData);
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
      final envelope = SentryEnvelope.fromEvent(
        sentryEvent,
        fixture.options.sdk,
        dsn: fixture.options.dsn,
      );

      mockRateLimiter.filter(envelope);

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
      final envelope = SentryEnvelope.fromEvent(
        sentryEvent,
        fixture.options.sdk,
        dsn: fixture.options.dsn,
      );
      await sut.send(envelope);

      expect(mockRateLimiter.errorCode, 200);
      expect(mockRateLimiter.retryAfterHeader, isNull);
      expect(mockRateLimiter.sentryRateLimitHeader,
          'fixture-sentryRateLimitHeader');
    });
  });

  group('sent_at', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('capture envelope sets sent_at in header', () async {
      final sentryEvent = SentryEvent();
      final envelope = SentryEnvelope.fromEvent(
        sentryEvent,
        fixture.options.sdk,
        dsn: fixture.options.dsn,
      );

      final httpMock = MockClient((http.Request request) async {
        return http.Response('{}', 200);
      });
      final sut = fixture.getSut(httpMock, MockRateLimiter());
      await sut.send(envelope);

      expect(envelope.header.sentAt, DateTime.utc(2019));
    });
  });

  group('client reports', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('does records lost event for error >= 400', () async {
      final httpMock = MockClient((http.Request request) async {
        return http.Response('{}', 400);
      });
      final sut = fixture.getSut(httpMock, MockRateLimiter());

      final sentryEvent = SentryEvent();
      final envelope = SentryEnvelope.fromEvent(
        sentryEvent,
        fixture.options.sdk,
        dsn: fixture.options.dsn,
      );
      await sut.send(envelope);

      expect(fixture.clientReportRecorder.discardedEvents.first.reason,
          DiscardReason.networkError);
      expect(fixture.clientReportRecorder.discardedEvents.first.category,
          DataCategory.error);
    });

    test('does records lost transaction and span for error >= 400', () async {
      final httpMock = MockClient((http.Request request) async {
        return http.Response('{}', 400);
      });
      final sut = fixture.getSut(httpMock, MockRateLimiter());

      final transaction = fixture.getTransaction();
      transaction.tracer.startChild('child1');
      transaction.tracer.startChild('child2');
      final envelope = SentryEnvelope.fromTransaction(
        transaction,
        fixture.options.sdk,
        dsn: fixture.options.dsn,
      );
      await sut.send(envelope);

      final transactionDiscardedEvent = fixture
          .clientReportRecorder.discardedEvents
          .firstWhereOrNull((element) =>
              element.category == DataCategory.transaction &&
              element.reason == DiscardReason.networkError);

      final spanDiscardedEvent = fixture.clientReportRecorder.discardedEvents
          .firstWhereOrNull((element) =>
              element.category == DataCategory.span &&
              element.reason == DiscardReason.networkError);

      expect(transactionDiscardedEvent, isNotNull);
      expect(spanDiscardedEvent, isNotNull);
      expect(spanDiscardedEvent!.quantity, 3);
    });

    test('does not record lost event for error 429', () async {
      final httpMock = MockClient((http.Request request) async {
        return http.Response('{}', 429);
      });
      final sut = fixture.getSut(httpMock, MockRateLimiter());

      final sentryEvent = SentryEvent();
      final envelope = SentryEnvelope.fromEvent(
        sentryEvent,
        fixture.options.sdk,
        dsn: fixture.options.dsn,
      );
      await sut.send(envelope);

      expect(fixture.clientReportRecorder.discardedEvents.isEmpty, isTrue);
    });

    test('does record lost event for error >= 500', () async {
      final httpMock = MockClient((http.Request request) async {
        return http.Response('{}', 500);
      });
      final sut = fixture.getSut(httpMock, MockRateLimiter());

      final sentryEvent = SentryEvent();
      final envelope = SentryEnvelope.fromEvent(
        sentryEvent,
        fixture.options.sdk,
        dsn: fixture.options.dsn,
      );
      await sut.send(envelope);

      expect(fixture.clientReportRecorder.discardedEvents.first.reason,
          DiscardReason.networkError);
      expect(fixture.clientReportRecorder.discardedEvents.first.category,
          DataCategory.error);
    });
  });
}

class Fixture {
  final options = defaultTestOptions();

  late var clientReportRecorder = MockClientReportRecorder();

  HttpTransport getSut(http.Client client, RateLimiter rateLimiter) {
    options.httpClient = client;
    options.recorder = clientReportRecorder;
    options.clock = () {
      return DateTime.utc(2019);
    };
    return HttpTransport(options, rateLimiter);
  }

  SentryTransaction getTransaction() {
    final context = SentryTransactionContext(
      'name',
      'op',
      samplingDecision: SentryTracesSamplingDecision(true),
    );
    final tracer = SentryTracer(context, MockHub());
    return SentryTransaction(tracer);
  }
}
