import 'package:sentry/sentry.dart';
import 'package:sentry/src/client_reports/discard_reason.dart';
import 'package:sentry/src/transport/data_category.dart';
import 'package:test/test.dart';

import 'package:sentry/src/transport/rate_limiter.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry/src/sentry_envelope_header.dart';

import '../mocks/mock_client_report_recorder.dart';
import '../mocks/mock_hub.dart';

void main() {
  var fixture = Fixture();

  setUp(() {
    fixture = Fixture();
  });

  test('uses X-Sentry-Rate-Limit and allows sending if time has passed', () {
    final rateLimiter = fixture.getSUT();
    fixture.dateTimeToReturn = 0;

    final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
    final envelope = SentryEnvelope(
      SentryEnvelopeHeader.newEventId(),
      [eventItem],
    );

    rateLimiter.updateRetryAfterLimits(
        '50:transaction:key, 1:default;error;security:organization', null, 1);

    fixture.dateTimeToReturn = 1001;

    final result = rateLimiter.filter(envelope);
    expect(result, isNotNull);
    expect(result!.items.length, 1);
  });

  test(
      'parse X-Sentry-Rate-Limit and set its values and retry after should be true',
      () {
    final rateLimiter = fixture.getSUT();
    fixture.dateTimeToReturn = 0;
    final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());

    final envelope = SentryEnvelope(
      SentryEnvelopeHeader.newEventId(),
      [eventItem],
    );

    rateLimiter.updateRetryAfterLimits(
        '50:transaction:key, 2700:default;error;security:organization',
        null,
        1);

    final result = rateLimiter.filter(envelope);
    expect(result, isNull);
  });

  test(
      'parse X-Sentry-Rate-Limit and set its values and retry after should be false',
      () {
    final rateLimiter = fixture.getSUT();
    fixture.dateTimeToReturn = 0;
    final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());

    final envelope = SentryEnvelope(
      SentryEnvelopeHeader.newEventId(),
      [eventItem],
    );

    rateLimiter.updateRetryAfterLimits(
        '1:transaction:key, 1:default;error;security:organization', null, 1);

    fixture.dateTimeToReturn = 1001;

    final result = rateLimiter.filter(envelope);
    expect(result, isNotNull);
    expect(1, result!.items.length);
  });

  test(
      'When X-Sentry-Rate-Limit categories are empty, applies to all the categories',
      () {
    final rateLimiter = fixture.getSUT();
    fixture.dateTimeToReturn = 0;
    final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
    final envelope = SentryEnvelope(
      SentryEnvelopeHeader.newEventId(),
      [eventItem],
    );

    rateLimiter.updateRetryAfterLimits('50::key', null, 1);

    final result = rateLimiter.filter(envelope);
    expect(result, isNull);
  });

  test(
      'When all categories is set but expired, applies only for specific category',
      () {
    final rateLimiter = fixture.getSUT();
    fixture.dateTimeToReturn = 0;
    final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
    final envelope = SentryEnvelope(
      SentryEnvelopeHeader.newEventId(),
      [eventItem],
    );

    rateLimiter.updateRetryAfterLimits(
        '1::key, 60:default;error;security:organization', null, 1);

    fixture.dateTimeToReturn = 1001;

    final result = rateLimiter.filter(envelope);
    expect(result, isNull);
  });

  test('When category has shorter rate limiting, do not apply new timestamp',
      () {
    final rateLimiter = fixture.getSUT();
    fixture.dateTimeToReturn = 0;
    final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
    final envelope = SentryEnvelope(
      SentryEnvelopeHeader.newEventId(),
      [eventItem],
    );

    rateLimiter.updateRetryAfterLimits(
        '60:error:key, 1:error:organization', null, 1);

    fixture.dateTimeToReturn = 1001;

    final result = rateLimiter.filter(envelope);
    expect(result, isNull);
  });

  test('When category has longer rate limiting, apply new timestamp', () {
    final rateLimiter = fixture.getSUT();
    fixture.dateTimeToReturn = 0;
    final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
    final envelope = SentryEnvelope(
      SentryEnvelopeHeader.newEventId(),
      [eventItem],
    );

    rateLimiter.updateRetryAfterLimits(
        '1:error:key, 5:error:organization', null, 1);

    fixture.dateTimeToReturn = 1001;

    final result = rateLimiter.filter(envelope);
    expect(result, isNull);
  });

  test('When both retry headers are not present, default delay is set', () {
    final rateLimiter = fixture.getSUT();
    fixture.dateTimeToReturn = 0;
    final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
    final envelope = SentryEnvelope(
      SentryEnvelopeHeader.newEventId(),
      [eventItem],
    );

    rateLimiter.updateRetryAfterLimits(null, null, 429);

    fixture.dateTimeToReturn = 1001;

    final result = rateLimiter.filter(envelope);
    expect(result, isNull);
  });

  test(
      'When no sentryRateLimitHeader available, it fallback to retryAfterHeader',
      () {
    final rateLimiter = fixture.getSUT();
    fixture.dateTimeToReturn = 0;
    final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
    final envelope = SentryEnvelope(
      SentryEnvelopeHeader.newEventId(),
      [eventItem],
    );

    rateLimiter.updateRetryAfterLimits(null, '50', 429);

    fixture.dateTimeToReturn = 1001;

    final result = rateLimiter.filter(envelope);
    expect(result, isNull);
  });

  test('dropping of event recorded', () {
    final rateLimiter = fixture.getSUT();

    final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
    final eventEnvelope = SentryEnvelope(
      SentryEnvelopeHeader.newEventId(),
      [eventItem],
    );

    rateLimiter.updateRetryAfterLimits(
        '1:error:key, 5:error:organization', null, 1);

    final result = rateLimiter.filter(eventEnvelope);
    expect(result, isNull);

    expect(fixture.mockRecorder.category, DataCategory.error);
    expect(fixture.mockRecorder.reason, DiscardReason.rateLimitBackoff);
  });

  test('dropping of transaction recorded', () {
    final rateLimiter = fixture.getSUT();

    final transaction = fixture.getTransaction();
    final eventItem = SentryEnvelopeItem.fromTransaction(transaction);
    final eventEnvelope = SentryEnvelope(
      SentryEnvelopeHeader.newEventId(),
      [eventItem],
    );

    rateLimiter.updateRetryAfterLimits(
        '1:transaction:key, 5:transaction:organization', null, 1);

    final result = rateLimiter.filter(eventEnvelope);
    expect(result, isNull);

    expect(fixture.mockRecorder.category, DataCategory.transaction);
    expect(fixture.mockRecorder.reason, DiscardReason.rateLimitBackoff);
  });
}

class Fixture {
  var dateTimeToReturn = 0;

  late var mockRecorder = MockClientReportRecorder();

  RateLimiter getSUT() {
    return RateLimiter(_currentDateTime, mockRecorder);
  }

  DateTime _currentDateTime() {
    return DateTime.fromMillisecondsSinceEpoch(dateTimeToReturn);
  }

  SentryTransaction getTransaction() {
    final context = SentryTransactionContext(
      'name',
      'op',
      sampled: true,
    );
    final tracer = SentryTracer(context, MockHub());
    return SentryTransaction(tracer);
  }
}
