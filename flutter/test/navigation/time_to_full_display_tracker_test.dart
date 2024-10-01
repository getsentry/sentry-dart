// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/navigation/time_to_full_display_tracker.dart';
import 'package:sentry/src/sentry_tracer.dart';

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

    await sut.track(transaction, fixture.startTimestamp);

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
  });

  test(
      'span finishes automatically after timeout with deadline_exceeded status',
      () async {
    final sut = fixture.getSut();
    final transaction = fixture.getTransaction() as SentryTracer;

    await sut.track(transaction, fixture.startTimestamp);

    final ttfdSpan = transaction.children.first;
    expect(transaction.children, hasLength(1));
    expect(ttfdSpan.endTimestamp, equals(fixture.endTimestampProvider()));
    expect(ttfdSpan.context.operation,
        equals(SentrySpanOperations.uiTimeToFullDisplay));
    expect(ttfdSpan.finished, isTrue);
    expect(ttfdSpan.status, equals(SpanStatus.deadlineExceeded()));
    expect(ttfdSpan.context.description, equals('Current route full display'));
    expect(ttfdSpan.origin, equals(SentryTraceOrigins.manualUiTimeToDisplay));
  });
}

class Fixture {
  final startTimestamp = getUtcDateTime();
  final hub = Hub(defaultTestOptions()..tracesSampleRate = 1.0);
  final autoFinishAfter = const Duration(seconds: 2);
  late final endTimestampProvider = fakeTTIDEndTimestampProvider();

  ISentrySpan getTransaction({String? name = "Current route"}) {
    return hub.startTransaction(name!, SentrySpanOperations.uiLoad,
        bindToScope: true, startTimestamp: startTimestamp);
  }

  EndTimestampProvider fakeTTIDEndTimestampProvider() =>
      () => startTimestamp.add(const Duration(seconds: 1));

  TimeToFullDisplayTracker getSut(
      {EndTimestampProvider? endTimestampProvider}) {
    endTimestampProvider ??= this.endTimestampProvider;
    return TimeToFullDisplayTracker(
        endTimestampProvider: endTimestampProvider,
        autoFinishAfter: autoFinishAfter);
  }
}
