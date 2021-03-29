import 'package:test/test.dart';

import 'package:sentry/src/transport/rate_limiter.dart';
import 'package:sentry/src/protocol/sentry_event.dart';
import 'package:sentry/src/sentry_envelope.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:sentry/src/sentry_envelope_item.dart';

import '../mocks/mock_current_data_time_provider.dart';

void main() {
  var fixture = Fixture();

  setUp(() {
    fixture = Fixture();
  });

  test('uses X-Sentry-Rate-Limit and allows sending if time has passed', () {
    final rateLimiter = fixture.getSUT();
    fixture.currentDateProvider.dateTimeToReturn = 0;

    final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
    final envelope = SentryEnvelope(SentryEnvelopeHeader.newEventId(), [eventItem]);

    rateLimiter.updateRetryAfterLimits(
        '50:transaction:key, 1:default;error;security:organization', null, 1);

    fixture.currentDateProvider.dateTimeToReturn = 1001;

    final result = rateLimiter.filter(envelope);
    expect(result, isNotNull);
    expect(result!.items.length, 1);
  });

  test(
      'parse X-Sentry-Rate-Limit and set its values and retry after should be true',
      () {
    final rateLimiter = fixture.getSUT();
    fixture.currentDateProvider.dateTimeToReturn = 0;
    final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());

    // TODO Add another envelope item with different type and update rate limit header

    // final transaction = SentryTransaction(
    //     SentryTracer(TransactionContext('name', 'op'), mock()));
    // final transactionItem =
    //     SentryEnvelopeItem.fromEvent(fixture.serializer, transaction);
    final envelope = SentryEnvelope(
        SentryEnvelopeHeader.newEventId(), [eventItem/*, transactionItem*/]);

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
    fixture.currentDateProvider.dateTimeToReturn = 0;
    final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());

    // TODO Add another envelope item with different type and update rate limit header

    // final transaction = SentryTransaction(
    //     SentryTracer(TransactionContext('name', 'op'), mock()));
    // final transactionItem = SentryEnvelopeItem.fromEvent(transaction);
    final envelope = SentryEnvelope(
        SentryEnvelopeHeader.newEventId(), [eventItem/*, transactionItem*/]);

    rateLimiter.updateRetryAfterLimits(
        '1:transaction:key, 1:default;error;security:organization', null, 1);

    fixture.currentDateProvider.dateTimeToReturn = 1001;

    final result = rateLimiter.filter(envelope);
    expect(result, isNotNull);
    expect(1, result!.items.length);
    //expect(2, result!.items.length); // TODO Update after added second item
  });

  test(
      'When X-Sentry-Rate-Limit categories are empty, applies to all the categories',
      () {
    final rateLimiter = fixture.getSUT();
    fixture.currentDateProvider.dateTimeToReturn = 0;
    final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
    final envelope = SentryEnvelope(SentryEnvelopeHeader.newEventId(), [eventItem]);

    rateLimiter.updateRetryAfterLimits('50::key', null, 1);

    final result = rateLimiter.filter(envelope);
    expect(result, isNull);
  });

  test(
      'When all categories is set but expired, applies only for specific category',
      () {
    final rateLimiter = fixture.getSUT();
    fixture.currentDateProvider.dateTimeToReturn = 0;
    final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
    final envelope = SentryEnvelope(SentryEnvelopeHeader.newEventId(), [eventItem]);

    rateLimiter.updateRetryAfterLimits(
        '1::key, 60:default;error;security:organization', null, 1);

    fixture.currentDateProvider.dateTimeToReturn = 1001;

    final result = rateLimiter.filter(envelope);
    expect(result, isNull);
  });

  test('When category has shorter rate limiting, do not apply new timestamp',
      () {
    final rateLimiter = fixture.getSUT();
    fixture.currentDateProvider.dateTimeToReturn = 0;
    final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
    final envelope = SentryEnvelope(SentryEnvelopeHeader.newEventId(), [eventItem]);

    rateLimiter.updateRetryAfterLimits(
        '60:error:key, 1:error:organization', null, 1);

    fixture.currentDateProvider.dateTimeToReturn = 1001;

    final result = rateLimiter.filter(envelope);
    expect(result, isNull);
  });

  test('When category has longer rate limiting, apply new timestamp', () {
    final rateLimiter = fixture.getSUT();
    fixture.currentDateProvider.dateTimeToReturn = 0;
    final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
    final envelope = SentryEnvelope(SentryEnvelopeHeader.newEventId(), [eventItem]);

    rateLimiter.updateRetryAfterLimits(
        '1:error:key, 5:error:organization', null, 1);

    fixture.currentDateProvider.dateTimeToReturn = 1001;

    final result = rateLimiter.filter(envelope);
    expect(result, isNull);
  });

  test('When both retry headers are not present, default delay is set', () {
    final rateLimiter = fixture.getSUT();
    fixture.currentDateProvider.dateTimeToReturn = 0;
    final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
    final envelope = SentryEnvelope(SentryEnvelopeHeader.newEventId(), [eventItem]);

    rateLimiter.updateRetryAfterLimits(null, null, 429);

    fixture.currentDateProvider.dateTimeToReturn = 1001;

    final result = rateLimiter.filter(envelope);
    expect(result, isNull);
  });
}

class Fixture {
  final currentDateProvider = MockCurrentDateTimeProvider();

  RateLimiter getSUT() {
    return RateLimiter(currentDateProvider);
  }
}
