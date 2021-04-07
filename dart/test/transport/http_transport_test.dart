import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:sentry/src/sentry_envelope_item.dart';
import 'package:sentry/src/sentry_envelope_item_header.dart';
import 'package:sentry/src/sentry_item_type.dart';
import 'package:test/test.dart';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/transport/http_transport.dart';

import '../mocks.dart';

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
    test('filter called', () async {
      final httpMock = MockClient((http.Request request) async {
        return http.Response('{}', 200);
      });

      final options =
          SentryOptions(dsn: 'https://public:secret@sentry.example.com/1')
            ..compressPayload = false
            ..httpClient = httpMock;

      final mockRateLimiter = MockRateLimiter();

      final sut = HttpTransport(options, mockRateLimiter);

      final sentryEnvelope = givenEnvelope();
      await sut.sendSentryEnvelope(sentryEnvelope);

      expect(mockRateLimiter.envelopeToFilter, sentryEnvelope);
    });

    test('send filtered event', () async {
      List<int>? body;

      final httpMock = MockClient((http.Request request) async {
        body = request.bodyBytes;
        return http.Response('{}', 200);
      });

      final filteredEnvelope = givenEnvelope();

      final mockRateLimiter = MockRateLimiter();
      mockRateLimiter.filteredEnvelope = filteredEnvelope;

      final options =
          SentryOptions(dsn: 'https://public:secret@sentry.example.com/1')
            ..compressPayload = false
            ..httpClient = httpMock;

      final sut = HttpTransport(options, mockRateLimiter);
      final sentryEvent = SentryEvent();
      await sut.sendSentryEvent(sentryEvent);

      expect(body, await filteredEnvelope.toEnvelope());
    });

    test('send nothing when filtered event null', () async {
      var httpCalled = false;
      final httpMock = MockClient((http.Request request) async {
        httpCalled = true;
        return http.Response('{}', 200);
      });

      final options =
          SentryOptions(dsn: 'https://public:secret@sentry.example.com/1')
            ..compressPayload = false
            ..httpClient = httpMock;

      final mockRateLimiter = MockRateLimiter();
      mockRateLimiter.filterReturnsNull = true;

      final sut = HttpTransport(options, mockRateLimiter);

      final sentryEvent = SentryEvent();
      final eventId = await sut.sendSentryEvent(sentryEvent);

      expect(eventId, isNull);
      expect(httpCalled, false);
    });
  });

  group('updateRetryAfterLimits', () {
    test('retryAfterHeader', () async {
      final httpMock = MockClient((http.Request request) async {
        return http.Response('{}', 429, headers: {'Retry-After': '1'});
      });

      final mockRateLimiter = MockRateLimiter();

      final options =
          SentryOptions(dsn: 'https://public:secret@sentry.example.com/1')
            ..httpClient = httpMock;

      final sut = HttpTransport(options, mockRateLimiter);
      final sentryEvent = SentryEvent();
      await sut.sendSentryEvent(sentryEvent);

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

      final options =
          SentryOptions(dsn: 'https://public:secret@sentry.example.com/1')
            ..httpClient = httpMock;

      final sut = HttpTransport(options, mockRateLimiter);
      final sentryEvent = SentryEvent();
      await sut.sendSentryEvent(sentryEvent);

      expect(mockRateLimiter.errorCode, 200);
      expect(mockRateLimiter.retryAfterHeader, isNull);
      expect(mockRateLimiter.sentryRateLimitHeader,
          'fixture-sentryRateLimitHeader');
    });
  });
}
