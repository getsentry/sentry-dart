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
    final transaction = fixture.getTransaction();
    const finishAfterDuration = Duration(seconds: 1);

    Future<void>.delayed(finishAfterDuration, () {
      sut.reportFullyDisplayed();
    });

    await sut.track(transaction: transaction);

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
    final transaction = fixture.getTransaction();

    final ttidEndTimestamp = fixture.fakeTTIDEndTimestamp();

    await sut.track(
      transaction: transaction,
      ttidEndTimestamp: ttidEndTimestamp,
    );

    final ttfdSpan = transaction.children.first;
    expect(transaction.children, hasLength(1));
    expect(ttfdSpan.endTimestamp, equals(ttidEndTimestamp));
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
    final transaction = fixture.getTransaction();
    const finishAfterDuration = Duration(seconds: 1);

    Future<void>.delayed(finishAfterDuration, () {
      sut.reportFullyDisplayed();
      sut.reportFullyDisplayed();
    });

    await sut.track(transaction: transaction);
  });

  test('finishing ttfd without starting tracker does not throw', () async {
    final sut = fixture.getSut();

    await sut.reportFullyDisplayed();
  });

  test('reportFullyDisplayed with span id does not finish unrelated span',
      () async {
    final sut = fixture.getSut();

    final transactionA = fixture.getTransaction(name: "a");
    unawaited(
      sut.track(
        transaction: transactionA,
      ),
    );
    await transactionA.finish();

    final transactionB = fixture.getTransaction(name: "b");
    unawaited(
      sut.track(
        transaction: transactionB,
      ),
    );

    // Don't await timeout to finish
    await sut.reportFullyDisplayed(spanId: transactionA.context.spanId);

    final ttfdSpanB = transactionB.children.first;
    expect(ttfdSpanB.finished, isFalse);
    expect(ttfdSpanB.status, isNull);

    await sut.reportFullyDisplayed(spanId: transactionB.context.spanId);

    expect(ttfdSpanB.finished, isTrue);
    expect(ttfdSpanB.status, SpanStatus.ok());
  });
}

class Fixture {
  final startTimestamp = getUtcDateTime();
  final hub = Hub(defaultTestOptions()..tracesSampleRate = 1.0);
  final autoFinishAfter = const Duration(seconds: 2);

  SentryTracer getTransaction({String? name}) {
    return hub.startTransaction(
      name ?? "Current route",
      SentrySpanOperations.uiLoad,
      bindToScope: true,
      startTimestamp: startTimestamp,
    ) as SentryTracer;
  }

  DateTime fakeTTIDEndTimestamp() =>
      startTimestamp.add(const Duration(seconds: 1));

  TimeToFullDisplayTracker getSut() {
    return TimeToFullDisplayTracker(autoFinishAfter);
  }
}
