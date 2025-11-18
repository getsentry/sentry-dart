import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/client_reports/discard_reason.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry/src/transport/data_category.dart';
import 'package:sentry/src/transport/rate_limiter.dart';
import 'package:test/test.dart';

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

    test('log', () {
      final rateLimiter = fixture.getSut();
      fixture.dateTimeToReturn = 0;

      final log = SentryLog(
        timestamp: DateTime.now(),
        traceId: SentryId.newId(),
        level: SentryLogLevel.info,
        body: 'test',
        attributes: {
          'test': SentryAttribute.string('test'),
        },
      );

      final sdkVersion = SdkVersion(name: 'test', version: 'test');
      final envelope = SentryEnvelope.fromLogs([log], sdkVersion);

      rateLimiter.updateRetryAfterLimits(
          '1:log_item:key, 5:log_item:organization', null, 1);

      final result = rateLimiter.filter(envelope);
      expect(result, isNull);
    });
  });

  group('$DataCategory', () {
    test('fromItemType', () {
      expect(DataCategory.fromItemType('event'), DataCategory.error);
      expect(DataCategory.fromItemType('session'), DataCategory.session);
      expect(DataCategory.fromItemType('attachment'), DataCategory.attachment);
      expect(
          DataCategory.fromItemType('transaction'), DataCategory.transaction);
      expect(DataCategory.fromItemType('statsd'), DataCategory.metricBucket);
      expect(DataCategory.fromItemType('log'), DataCategory.logItem);
      expect(DataCategory.fromItemType('unknown'), DataCategory.unknown);
    });
  });

  group('RateLimiter logging', () {
    test('logs warning for dropped item and full envelope', () {
      final options = defaultTestOptions();
      options.debug = false;
      options.diagnosticLevel = SentryLevel.warning;

      final logCalls = <_LogCall>[];
      void mockLogger(
        SentryLevel level,
        String message, {
        String? logger,
        Object? exception,
        StackTrace? stackTrace,
      }) {
        logCalls.add(_LogCall(level, message));
      }

      options.log = mockLogger;

      final rateLimiter = RateLimiter(options);

      final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
      final envelope = SentryEnvelope(
        SentryEnvelopeHeader.newEventId(),
        [eventItem],
      );

      // Apply rate limit for error (event)
      rateLimiter.updateRetryAfterLimits(
          '1:error:key, 5:error:organization', null, 1);

      // Filter should drop the entire envelope
      final result = rateLimiter.filter(envelope);
      expect(result, isNull);

      // Expect 2 warning logs: item dropped + all items dropped
      expect(logCalls.length, 2);

      final itemLog = logCalls[0];
      expect(itemLog.level, SentryLevel.warning);
      expect(
        itemLog.message,
        contains(
            'Envelope item of type "event" was dropped due to rate limiting'),
      );

      final fullDropLog = logCalls[1];
      expect(fullDropLog.level, SentryLevel.warning);
      expect(
        fullDropLog.message,
        contains('Envelope was dropped due to rate limiting'),
      );

      expect(options.debug, isFalse);
    });

    test('logs warning for each dropped item only when some items are sent',
        () {
      final options = defaultTestOptions();
      options.debug = false;
      options.diagnosticLevel = SentryLevel.warning;

      final logCalls = <_LogCall>[];
      void mockLogger(
        SentryLevel level,
        String message, {
        String? logger,
        Object? exception,
        StackTrace? stackTrace,
      }) {
        logCalls.add(_LogCall(level, message));
      }

      options.log = mockLogger;

      final rateLimiter = RateLimiter(options);

      // One event (error) and one transaction
      final eventItem = SentryEnvelopeItem.fromEvent(SentryEvent());
      final transaction = fixture.getTransaction();
      final transactionItem = SentryEnvelopeItem.fromTransaction(transaction);

      final envelope = SentryEnvelope(
        SentryEnvelopeHeader.newEventId(),
        [eventItem, transactionItem],
      );

      // Apply rate limit only for errors so the transaction can still be sent
      rateLimiter.updateRetryAfterLimits('60:error:key', null, 1);

      final result = rateLimiter.filter(envelope);
      expect(result, isNotNull);
      expect(result!.items.length, 1);
      expect(result.items.first.header.type, 'transaction');

      // Expect only 1 warning log: per-item drop (no summary)
      expect(logCalls.length, 1);

      final itemLog = logCalls.first;
      expect(itemLog.level, SentryLevel.warning);
      expect(
        itemLog.message,
        contains(
            'Envelope item of type "event" was dropped due to rate limiting'),
      );

      expect(options.debug, isFalse);
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

class _LogCall {
  final SentryLevel level;
  final String message;

  _LogCall(this.level, this.message);
}
