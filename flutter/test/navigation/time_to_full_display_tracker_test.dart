import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/navigation/time_to_full_display_tracker.dart';
import 'package:sentry/src/sentry_tracer.dart';

import '../mocks.dart';

void main() {
  late Fixture fixture;
  late SentryTracer transaction;
  late DateTime startTimestamp;
  late EndTimestampProvider endTimestampProvider;
  const routeName = 'regular route';

  setUp(() {
    fixture = Fixture();
    transaction = fixture.hub.startTransaction('test_transaction', 'test')
        as SentryTracer;

    // start timestamp needs to be after the transaction has started
    startTimestamp = DateTime.now().toUtc();
    endTimestampProvider = FakeTTIDEndTimeStampProvider(startTimestamp);
  });

  test('reportFullyDisplayed() marks the TTFD span as finished', () async {
    final sut = fixture.getSut(endTimestampProvider);

    sut.startTracking(transaction, startTimestamp, routeName);
    await sut.reportFullyDisplayed();

    final ttfdSpan = transaction.children.first;
    expect(transaction.children, hasLength(1));
    expect(ttfdSpan.context.operation,
        equals(SentrySpanOperations.uiTimeToFullDisplay));
    expect(ttfdSpan.finished, isTrue);
    expect(ttfdSpan.context.description, equals('$routeName full display'));
    expect(ttfdSpan.origin, equals(SentryTraceOrigins.manualUiTimeToDisplay));
  });

  test(
      'TTFD span finishes automatically after timeout with correct status and end time',
      () async {
    final sut = fixture.getSut(endTimestampProvider);

    sut.startTracking(transaction, startTimestamp, routeName);

    // Simulate delay to trigger automatic finish
    await Future.delayed(
        fixture.autoFinishAfter + const Duration(milliseconds: 100));

    final ttfdSpan = transaction.children.first;
    expect(transaction.children, hasLength(1));
    expect(ttfdSpan.endTimestamp, equals(endTimestampProvider.endTimestamp));
    expect(ttfdSpan.context.operation,
        equals(SentrySpanOperations.uiTimeToFullDisplay));
    expect(ttfdSpan.finished, isTrue);
    expect(ttfdSpan.status, equals(SpanStatus.deadlineExceeded()));
    expect(ttfdSpan.context.description, equals('$routeName full display'));
    expect(ttfdSpan.origin, equals(SentryTraceOrigins.manualUiTimeToDisplay));
  });
}

class Fixture {
  final hub = Hub(SentryFlutterOptions(dsn: fakeDsn)..tracesSampleRate = 1.0);
  final autoFinishAfter = const Duration(milliseconds: 100);

  TimeToFullDisplayTracker getSut(EndTimestampProvider endTimestampProvider) {
    return TimeToFullDisplayTracker(
        endTimestampProvider: endTimestampProvider,
        autoFinishAfter: autoFinishAfter);
  }
}

class FakeTTIDEndTimeStampProvider implements EndTimestampProvider {
  final DateTime _endTimestamp;

  FakeTTIDEndTimeStampProvider(DateTime startTimestamp)
      : _endTimestamp = startTimestamp.add(const Duration(seconds: 1)).toUtc();

  @override
  DateTime? get endTimestamp => _endTimestamp;
}
