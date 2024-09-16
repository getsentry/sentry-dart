import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/client_reports/discard_reason.dart';
import 'package:sentry/src/transport/data_category.dart';
import 'package:test/test.dart';

import 'package:sentry/src/transport/rate_limiter.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry/src/sentry_envelope_header.dart';

import '../mocks/mock_client_report_recorder.dart';
import '../mocks/mock_hub.dart';
import '../test_utils.dart';

void main() {
  var fixture = Fixture();

  setUp(() {
    fixture = Fixture();
  });

  test('uses X-Sentry-Rate-Limit and allows sending if time has passed', () {
    final rateLimiter = fixture.getSut();
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
    final rateLimiter = fixture.getSut();
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
    final rateLimiter = fixture.getSut();
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
    final rateLimiter = fixture.getSut();
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
    final rateLimiter = fixture.getSut();
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
    final rateLimiter = fixture.getSut();
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
    final rateLimiter = fixture.getSut();
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
    final rateLimiter = fixture.getSut();
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
    final rateLimiter = fixture.getSut();
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
    final rateLimiter = fixture.getSut();

    final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
    final eventEnvelope = SentryEnvelope(
      SentryEnvelopeHeader.newEventId(),
      [eventItem],
    );

    rateLimiter.updateRetryAfterLimits(
        '1:error:key, 5:error:organization', null, 1);

    final result = rateLimiter.filter(eventEnvelope);
    expect(result, isNull);

    expect(fixture.mockRecorder.discardedEvents.first.category,
        DataCategory.error);
    expect(fixture.mockRecorder.discardedEvents.first.reason,
        DiscardReason.rateLimitBackoff);
  });

  test('dropping of transaction recorded', () {
    final rateLimiter = fixture.getSut();

    final transaction = fixture.getTransaction();
    transaction.tracer.startChild('child1');
    transaction.tracer.startChild('child2');
    final eventItem = SentryEnvelopeItem.fromTransaction(transaction);
    final eventEnvelope = SentryEnvelope(
      SentryEnvelopeHeader.newEventId(),
      [eventItem],
    );

    rateLimiter.updateRetryAfterLimits(
        '1:transaction:key, 5:transaction:organization', null, 1);

    final result = rateLimiter.filter(eventEnvelope);
    expect(result, isNull);

    expect(fixture.mockRecorder.discardedEvents.length, 2);

    final transactionDiscardedEvent = fixture.mockRecorder.discardedEvents
        .firstWhereOrNull((element) =>
            element.category == DataCategory.transaction &&
            element.reason == DiscardReason.rateLimitBackoff);

    final spanDiscardedEvent = fixture.mockRecorder.discardedEvents
        .firstWhereOrNull((element) =>
            element.category == DataCategory.span &&
            element.reason == DiscardReason.rateLimitBackoff);

    expect(transactionDiscardedEvent, isNotNull);
    expect(spanDiscardedEvent, isNotNull);
    expect(spanDiscardedEvent!.quantity, 3);
  });

  test('dropping of metrics recorded', () {
    final rateLimiter = fixture.getSut();

    final metricsItem = SentryEnvelopeItem.fromMetrics({});
    final eventEnvelope = SentryEnvelope(
      SentryEnvelopeHeader.newEventId(),
      [metricsItem],
    );

    rateLimiter.updateRetryAfterLimits(
        '1:metric_bucket:key, 5:metric_bucket:organization', null, 1);

    final result = rateLimiter.filter(eventEnvelope);
    expect(result, isNull);

    expect(fixture.mockRecorder.discardedEvents.first.category,
        DataCategory.metricBucket);
    expect(fixture.mockRecorder.discardedEvents.first.reason,
        DiscardReason.rateLimitBackoff);
  });

  group('apply rateLimit', () {
    test('error', () {
      final rateLimiter = fixture.getSut();
      fixture.dateTimeToReturn = 0;

      final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
      final envelope = SentryEnvelope(
        SentryEnvelopeHeader.newEventId(),
        [eventItem],
      );

      rateLimiter.updateRetryAfterLimits(
          '1:error:key, 5:error:organization', null, 1);

      expect(rateLimiter.filter(envelope), isNull);
    });

    test('transaction', () {
      final rateLimiter = fixture.getSut();
      fixture.dateTimeToReturn = 0;

      final transaction = fixture.getTransaction();
      final eventItem = SentryEnvelopeItem.fromTransaction(transaction);
      final envelope = SentryEnvelope(
        SentryEnvelopeHeader.newEventId(),
        [eventItem],
      );

      rateLimiter.updateRetryAfterLimits(
          '1:transaction:key, 5:transaction:organization', null, 1);

      final result = rateLimiter.filter(envelope);
      expect(result, isNull);
    });

    test('metrics', () {
      final rateLimiter = fixture.getSut();
      fixture.dateTimeToReturn = 0;

      final metricsItem = SentryEnvelopeItem.fromMetrics({});
      final envelope = SentryEnvelope(
        SentryEnvelopeHeader.newEventId(),
        [metricsItem],
      );

      rateLimiter.updateRetryAfterLimits(
          '1:metric_bucket:key, 5:metric_bucket:organization', null, 1);

      final result = rateLimiter.filter(envelope);
      expect(result, isNull);
    });

    test('metrics with empty namespaces', () {
      final rateLimiter = fixture.getSut();
      fixture.dateTimeToReturn = 0;

      final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
      final metricsItem = SentryEnvelopeItem.fromMetrics({});
      final envelope = SentryEnvelope(
        SentryEnvelopeHeader.newEventId(),
        [eventItem, metricsItem],
      );

      rateLimiter.updateRetryAfterLimits(
          '10:metric_bucket:key:quota_exceeded:', null, 1);

      final result = rateLimiter.filter(envelope);
      expect(result, isNotNull);
      expect(result!.items.length, 1);
      expect(result.items.first.header.type, 'event');
    });

    test('metrics with custom namespace', () {
      final rateLimiter = fixture.getSut();
      fixture.dateTimeToReturn = 0;

      final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
      final metricsItem = SentryEnvelopeItem.fromMetrics({});
      final envelope = SentryEnvelope(
        SentryEnvelopeHeader.newEventId(),
        [eventItem, metricsItem],
      );

      rateLimiter.updateRetryAfterLimits(
          '10:metric_bucket:key:quota_exceeded:custom', null, 1);

      final result = rateLimiter.filter(envelope);
      expect(result, isNotNull);
      expect(result!.items.length, 1);
      expect(result.items.first.header.type, 'event');
    });
  });
}

class Fixture {
  var dateTimeToReturn = 0;

  late var mockRecorder = MockClientReportRecorder();

  RateLimiter getSut() {
    final options = defaultTestOptions();
    options.clock = _currentDateTime;
    options.recorder = mockRecorder;

    return RateLimiter(options);
  }

  DateTime _currentDateTime() {
    return DateTime.fromMillisecondsSinceEpoch(dateTimeToReturn);
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
