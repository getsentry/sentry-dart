// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/navigation/time_to_full_display_tracker.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'dart:async';

import '../mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('reportFullyDisplayed() finishes span', () async {
    final sut = fixture.getSut();
    final transaction = fixture.getTransaction() as SentryTracer;
    const finishAfterDuration = Duration(seconds: 1);

    Future<void>.delayed(finishAfterDuration, () {
      sut.reportFullyDisplayed();
    });

    await sut.track(
      transaction: transaction,
      startTimestamp: fixture.startTimestamp,
      routeName: fixture.latestTransactionName,
    );

    final ttfdSpan = transaction.children.first;
    expect(transaction.children, hasLength(1));
    expect(ttfdSpan.context.operation,
        equals(SentrySpanOperations.uiTimeToFullDisplay));
    expect(ttfdSpan.finished, isTrue);
    expect(ttfdSpan.context.description, equals('Current route full display'));
    expect(ttfdSpan.origin, equals(SentryTraceOrigins.manualUiTimeToDisplay));
    expect(ttfdSpan.startTimestamp, equals(fixture.startTimestamp));

    // Ensure endTimestamp is within an acceptable range
    final expectedEndTimestamp =
        fixture.startTimestamp.add(finishAfterDuration);
    final actualEndTimestamp = ttfdSpan.endTimestamp!;
    final differenceInSeconds =
        actualEndTimestamp.difference(expectedEndTimestamp).inSeconds.abs();
    expect(differenceInSeconds, lessThanOrEqualTo(1));
    expect(transaction.measurements, isNotEmpty);
  });

  test(
      'span finishes automatically after timeout with deadline_exceeded status',
      () async {
    final sut = fixture.getSut();
    final transaction = fixture.getTransaction() as SentryTracer;

    await sut.track(
      transaction: transaction,
      startTimestamp: fixture.startTimestamp,
      routeName: fixture.latestTransactionName,
    );

    final ttfdSpan = transaction.children.first;
    expect(transaction.children, hasLength(1));
    expect(ttfdSpan.endTimestamp, equals(fixture.endTimestampProvider()));
    expect(ttfdSpan.context.operation,
        equals(SentrySpanOperations.uiTimeToFullDisplay));
    expect(ttfdSpan.finished, isTrue);
    expect(ttfdSpan.status, equals(SpanStatus.deadlineExceeded()));
    expect(ttfdSpan.context.description, equals('Current route full display'));
    expect(ttfdSpan.origin, equals(SentryTraceOrigins.manualUiTimeToDisplay));
    expect(transaction.measurements, isEmpty);
  });

  test('finishing ttfd twice does not throw', () async {
    final sut = fixture.getSut();
    final transaction = fixture.getTransaction() as SentryTracer;
    const finishAfterDuration = Duration(seconds: 1);

    Future<void>.delayed(finishAfterDuration, () {
      sut.reportFullyDisplayed();
      sut.reportFullyDisplayed();
    });

    await sut.track(
      transaction: transaction,
      startTimestamp: fixture.startTimestamp,
      routeName: fixture.latestTransactionName,
    );
  });

  test('finishing ttfd without starting tracker does not throw', () async {
    final sut = fixture.getSut();

    await sut.reportFullyDisplayed();
  });

  test('reportFullyDisplayed with name does not finish unrelated span',
      () async {
    final sut = fixture.getSut();

    final transactionA = fixture.getTransaction(name: "a") as SentryTracer;
    unawaited(
      sut.track(
        transaction: transactionA,
        startTimestamp: fixture.startTimestamp,
        routeName: fixture.latestTransactionName,
      ),
    );
    await transactionA.finish();

    final transactionB = fixture.getTransaction(name: "b") as SentryTracer;
    unawaited(
      sut.track(
        transaction: transactionB,
        startTimestamp: fixture.startTimestamp,
        routeName: fixture.latestTransactionName,
      ),
    );

    // Don't await timeout to finish
    await sut.reportFullyDisplayed(routeName: "a");

    final ttfdSpanB = transactionB.children.first;
    expect(ttfdSpanB.finished, isFalse);
    expect(ttfdSpanB.status, isNull);

    await sut.reportFullyDisplayed(routeName: "b");

    expect(ttfdSpanB.finished, isTrue);
    expect(ttfdSpanB.status, SpanStatus.ok());
  });
}

class Fixture {
  final startTimestamp = getUtcDateTime();
  final hub = Hub(defaultTestOptions()..tracesSampleRate = 1.0);
  final autoFinishAfter = const Duration(seconds: 2);
  late final endTimestampProvider = fakeTTIDEndTimestampProvider();

  late String latestTransactionName;

  ISentrySpan getTransaction({String? name}) {
    latestTransactionName = name ?? "Current route";
    return hub.startTransaction(
      latestTransactionName,
      SentrySpanOperations.uiLoad,
      bindToScope: true,
      startTimestamp: startTimestamp,
    );
  }

  EndTimestampProvider fakeTTIDEndTimestampProvider() =>
      () => startTimestamp.add(const Duration(seconds: 1));

  TimeToFullDisplayTracker getSut(
      {EndTimestampProvider? endTimestampProvider}) {
    endTimestampProvider ??= this.endTimestampProvider;
    return TimeToFullDisplayTracker(
      endTimestampProvider: endTimestampProvider,
      autoFinishAfter: autoFinishAfter,
    );
  }
}
