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

      await sut.track(transaction, endTimestamp: endTimestamp);

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

    test('calls ttfd/ttid clear', () async {
      fixture.options.enableTimeToFullDisplayTracing = true;

      final sut = fixture.getSut();

      final transaction = fixture.getTransaction();
      await sut.cancelUnfinishedSpans(transaction, transaction.startTimestamp);

      verify(fixture.ttidTracker.clear()).called(1);
      verify(fixture.ttfdTracker.clear()).called(1);
    });
  });

  group('currentTransaction', () {
    test('is set when tracking', () async {
      final transaction = fixture.getTransaction();
      final ttidTransaction = fixture.getTTIDTransaction(transaction);
      when(fixture.ttidTracker.track(transaction: transaction))
          .thenAnswer((_) async => ttidTransaction);

      final sut = fixture.getSut();
      unawaited(sut.track(transaction));

      expect(sut.currentTransaction, equals(transaction));
    });

    test('is not set when not tracking', () async {
      final sut = fixture.getSut();

      expect(sut.currentTransaction, isNull);
    });
    test('is reset when clear is called', () async {
      final transaction = fixture.getTransaction();
      final ttidTransaction = fixture.getTTIDTransaction(transaction);
      when(fixture.ttidTracker.track(transaction: transaction))
          .thenAnswer((_) async => ttidTransaction);

      final sut = fixture.getSut();
      unawaited(sut.track(transaction));
      sut.clear();

      expect(sut.currentTransaction, isNull);
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
