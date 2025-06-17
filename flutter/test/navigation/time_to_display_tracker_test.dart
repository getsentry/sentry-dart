// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: inference_failure_on_instance_creation

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';
import 'package:mockito/mockito.dart';
import 'dart:async';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('track', () {
    test('calls ttid tracker', () async {
      final sut = fixture.getSut();

      final transaction = fixture.getTransaction();
      final ttidTransaction = fixture.getTTIDTransaction(transaction);
      when(fixture.ttidTracker.track(transaction: transaction))
          .thenAnswer((_) async => ttidTransaction);

      await sut.track(transaction);

      verify(fixture.ttidTracker.track(transaction: transaction)).called(1);
    });

    test('calls ttid tracker with endTimestamp', () async {
      final sut = fixture.getSut();
      final endTimestamp =
          fixture.startTimestamp.add(Duration(milliseconds: 100));

      final transaction = fixture.getTransaction();
      final ttidTransaction = fixture.getTTIDTransaction(transaction);
      when(fixture.ttidTracker.track(
              transaction: transaction, endTimestamp: anyNamed('endTimestamp')))
          .thenAnswer((_) async => ttidTransaction);

      await sut.track(transaction, ttidEndTimestamp: endTimestamp);

      verify(fixture.ttidTracker.track(
        transaction: transaction,
        endTimestamp: endTimestamp,
      )).called(1);
    });

    test('calls ttfd tracker', () async {
      fixture.options.enableTimeToFullDisplayTracing = true;

      final sut = fixture.getSut();

      final transaction = fixture.getTransaction();
      final ttidTransaction = fixture.getTTIDTransaction(transaction);
      when(fixture.ttidTracker.track(transaction: transaction))
          .thenAnswer((_) async => ttidTransaction);

      await sut.track(transaction);

      verify(fixture.ttfdTracker.track(transaction: transaction)).called(1);
    });

    test('track does not call ttid tracker if disabled', () async {
      fixture.options.enableTimeToFullDisplayTracing = false;

      final sut = fixture.getSut();

      final transaction = fixture.getTransaction();
      final ttidTransaction = fixture.getTTIDTransaction(transaction);
      when(fixture.ttidTracker.track(transaction: transaction))
          .thenAnswer((_) async => ttidTransaction);

      await sut.track(transaction);

      verify(fixture.ttidTracker.track(transaction: transaction)).called(1);
    });

    test('track calls ttdf tracker with ttid end timestamp', () async {
      fixture.options.enableTimeToFullDisplayTracing = true;

      final sut = fixture.getSut();

      final ttidEndTimestamp =
          fixture.startTimestamp.add(Duration(milliseconds: 75));

      final transaction = fixture.getTransaction();
      final ttidTransaction = fixture.getTTIDTransaction(transaction);
      await ttidTransaction.finish(endTimestamp: ttidEndTimestamp);
      when(fixture.ttidTracker.track(transaction: transaction))
          .thenAnswer((_) async => ttidTransaction);

      await sut.track(transaction);

      verify(fixture.ttfdTracker.track(
        transaction: transaction,
        ttidEndTimestamp: ttidEndTimestamp,
      )).called(1);
    });
  });

  group('clear', () {
    test('calls ttfd/ttid clear', () async {
      fixture.options.enableTimeToFullDisplayTracing = true;

      final sut = fixture.getSut();
      sut.clear();

      verify(fixture.ttidTracker.clear()).called(1);
      verify(fixture.ttfdTracker.clear()).called(1);
    });
  });

  group('cancelUnfinishedSpans', () {
    test('cancels unfinished ttid/ttfd spans', () async {
      final transaction = fixture.getTransaction();

      final ttidSpan = transaction.startChild(
        SentrySpanOperations.uiTimeToInitialDisplay,
        description: 'Current route initial display',
        startTimestamp: transaction.startTimestamp,
      );

      final ttfdSpan = transaction.startChild(
        SentrySpanOperations.uiTimeToFullDisplay,
        description: 'Current route full display',
        startTimestamp: transaction.startTimestamp,
      );

      final sut = fixture.getSut();

      final endTimestamp =
          transaction.startTimestamp.add(Duration(milliseconds: 100));
      await sut.cancelUnfinishedSpans(transaction, endTimestamp);

      expect(ttidSpan.finished, isTrue);
      expect(ttidSpan.status, SpanStatus.deadlineExceeded());
      expect(ttidSpan.endTimestamp, endTimestamp);

      expect(ttfdSpan.finished, isTrue);
      expect(ttfdSpan.status, SpanStatus.deadlineExceeded());
      expect(ttfdSpan.endTimestamp, endTimestamp);
    });

    test('unfinished ttfd will match ttid duration if available', () async {
      final transaction = fixture.getTransaction();
      final ttidEndTimestamp =
          transaction.startTimestamp.add(Duration(milliseconds: 50));

      final ttidSpan = transaction.startChild(
        SentrySpanOperations.uiTimeToInitialDisplay,
        description: 'Current route initial display',
        startTimestamp: transaction.startTimestamp,
      );
      await ttidSpan.finish(endTimestamp: ttidEndTimestamp);

      final ttfdSpan = transaction.startChild(
        SentrySpanOperations.uiTimeToFullDisplay,
        description: 'Current route full display',
        startTimestamp: transaction.startTimestamp,
      );

      final sut = fixture.getSut();

      final endTimestamp =
          transaction.startTimestamp.add(Duration(milliseconds: 100));
      await sut.cancelUnfinishedSpans(transaction, endTimestamp);

      expect(ttfdSpan.finished, isTrue);
      expect(ttfdSpan.status, SpanStatus.deadlineExceeded());
      expect(ttfdSpan.endTimestamp, ttidEndTimestamp);
    });
  });

  group('transactionId', () {
    test('is set when tracking', () async {
      final transaction = fixture.getTransaction();
      final ttidTransaction = fixture.getTTIDTransaction(transaction);
      when(fixture.ttidTracker.track(transaction: transaction))
          .thenAnswer((_) async => ttidTransaction);

      final sut = fixture.getSut();
      unawaited(sut.track(transaction));

      expect(sut.transactionId, equals(transaction.context.spanId));
    });

    test('is not set when not tracking', () async {
      final sut = fixture.getSut();

      expect(sut.transactionId, isNull);
    });
    test('is reset when clear is called', () async {
      final transaction = fixture.getTransaction();
      final ttidTransaction = fixture.getTTIDTransaction(transaction);
      when(fixture.ttidTracker.track(transaction: transaction))
          .thenAnswer((_) async => ttidTransaction);

      final sut = fixture.getSut();
      unawaited(sut.track(transaction));
      sut.clear();

      expect(sut.transactionId, isNull);
    });
  });

  group('pending ttfd end timestamp', () {
    test('ttfd before track sets pending ttfd end timestamp', () async {
      fixture.options.enableTimeToFullDisplayTracing = true;

      final sut = fixture.getSut();
      final spanId = SpanId.newId();
      sut.transactionId = spanId;

      when(fixture.ttfdTracker.reportFullyDisplayed(
        spanId: spanId,
        endTimestamp: anyNamed('endTimestamp'),
      )).thenAnswer((_) async => false);

      final endTimestamp = DateTime.now().add(Duration(milliseconds: 100));
      await sut.reportFullyDisplayed(
          spanId: spanId, endTimestamp: endTimestamp);

      expect(sut.pendingTTFDEndTimestamp, endTimestamp);
    });

    test('ttfd after track does not set pending ttfd', () async {
      fixture.options.enableTimeToFullDisplayTracing = true;

      final sut = fixture.getSut();
      final spanId = SpanId.newId();
      sut.transactionId = spanId;

      when(fixture.ttfdTracker.reportFullyDisplayed(
        spanId: spanId,
        endTimestamp: anyNamed('endTimestamp'),
      )).thenAnswer((_) async => true);

      final endTimestamp = DateTime.now().add(Duration(milliseconds: 100));
      await sut.reportFullyDisplayed(
          spanId: spanId, endTimestamp: endTimestamp);

      expect(sut.pendingTTFDEndTimestamp, isNull);
    });

    test(
        'ttfd before track does not set pending ttfd end timestamp if spanId does not match',
        () async {
      fixture.options.enableTimeToFullDisplayTracing = true;

      final sut = fixture.getSut();
      final spanId = SpanId.newId();
      sut.transactionId = SpanId.newId();

      when(fixture.ttfdTracker.reportFullyDisplayed(
        spanId: spanId,
        endTimestamp: anyNamed('endTimestamp'),
      )).thenAnswer((_) async => false);

      final endTimestamp = DateTime.now().add(Duration(milliseconds: 100));
      await sut.reportFullyDisplayed(
          spanId: spanId, endTimestamp: endTimestamp);

      expect(sut.pendingTTFDEndTimestamp, isNull);
    });

    test('track uses pending ttfd', () async {
      fixture.options.enableTimeToFullDisplayTracing = true;

      final sut = fixture.getSut();
      final transaction = fixture.getTransaction();
      final ttidTransaction = fixture.getTTIDTransaction(transaction);
      when(fixture.ttidTracker.track(transaction: transaction))
          .thenAnswer((_) async => ttidTransaction);

      final spanId = transaction.context.spanId;
      sut.transactionId = spanId;

      when(fixture.ttfdTracker.reportFullyDisplayed(
        spanId: spanId,
        endTimestamp: anyNamed('endTimestamp'),
      )).thenAnswer((_) async => false);

      final endTimestamp = DateTime.now().add(Duration(milliseconds: 100));

      await sut.reportFullyDisplayed(
        spanId: spanId,
        endTimestamp: endTimestamp,
      );
      await sut.track(transaction);

      verify(fixture.ttfdTracker.track(
        transaction: anyNamed('transaction'),
        ttfdEndTimestamp: endTimestamp,
      )).called(1);
    });

    test('track with unrelated transaction resets pending ttfd', () async {
      fixture.options.enableTimeToFullDisplayTracing = true;

      final sut = fixture.getSut();

      final spanId = SpanId.newId();
      sut.transactionId = spanId;

      when(fixture.ttfdTracker.reportFullyDisplayed(
        spanId: spanId,
        endTimestamp: anyNamed('endTimestamp'),
      )).thenAnswer((_) async => false);

      final endTimestamp = DateTime.now().add(Duration(milliseconds: 100));

      await sut.reportFullyDisplayed(
        spanId: spanId,
        endTimestamp: endTimestamp,
      );

      final transaction = fixture.getTransaction();
      final ttidTransaction = fixture.getTTIDTransaction(transaction);
      when(fixture.ttidTracker.track(transaction: transaction))
          .thenAnswer((_) async => ttidTransaction);

      await sut.track(transaction);

      expect(sut.pendingTTFDEndTimestamp, isNull);
    });

    test('track falls back to ttid if pending ttfd is before ttid', () async {
      fixture.options.enableTimeToFullDisplayTracing = true;

      final sut = fixture.getSut();
      final transaction = fixture.getTransaction();

      // TTFD
      final spanId = transaction.context.spanId;
      sut.transactionId = spanId;

      when(fixture.ttfdTracker.reportFullyDisplayed(
        spanId: spanId,
        endTimestamp: anyNamed('endTimestamp'),
      )).thenAnswer((_) async => false);

      // TTID

      final ttidEndTimestamp = DateTime.now();
      final ttidTransaction = fixture.getTTIDTransaction(transaction);
      await ttidTransaction.finish(endTimestamp: ttidEndTimestamp);

      when(fixture.ttidTracker
              .track(transaction: transaction, endTimestamp: ttidEndTimestamp))
          .thenAnswer((_) async => ttidTransaction);

      final endTimestamp = ttidEndTimestamp.add(Duration(milliseconds: -100));

      await sut.reportFullyDisplayed(
        spanId: spanId,
        endTimestamp: endTimestamp,
      );
      await sut.track(transaction, ttidEndTimestamp: ttidEndTimestamp);

      verify(fixture.ttfdTracker.track(
        transaction: anyNamed('transaction'),
        ttidEndTimestamp: ttidTransaction.endTimestamp,
        ttfdEndTimestamp: ttidTransaction.endTimestamp,
      )).called(1);
    });
  });
}

class Fixture {
  final startTimestamp = getUtcDateTime();
  final options = defaultTestOptions()
    ..dsn = fakeDsn
    ..tracesSampleRate = 1.0;
  late final hub = Hub(options);

  late MockTimeToInitialDisplayTracker ttidTracker =
      MockTimeToInitialDisplayTracker();
  late MockTimeToFullDisplayTracker ttfdTracker =
      MockTimeToFullDisplayTracker();

  var latestTransactionName = 'Current route';

  SentryTracer getTransaction({String? name}) {
    latestTransactionName = name ?? 'Current route';
    return hub.startTransaction(
      latestTransactionName,
      'ui.load',
      startTimestamp: startTimestamp,
    ) as SentryTracer;
  }

  ISentrySpan getTTIDTransaction(SentryTracer parent) {
    return parent.startChild(
      SentrySpanOperations.uiTimeToInitialDisplay,
      description: 'Current route initial display',
      startTimestamp: parent.startTimestamp,
    );
  }

  TimeToDisplayTracker getSut() {
    return TimeToDisplayTracker(
      ttidTracker: ttidTracker,
      ttfdTracker: ttfdTracker,
      options: options,
    );
  }
}
