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

  test('reportFullyDisplayed() finishes TTFD span', () async {
    final sut = fixture.getSut();
    final transaction = fixture.getTransaction() as SentryTracer;

    Future<void>.delayed(const Duration(seconds: 1), () {
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
  });

  test(
      'TTFD span finishes automatically after timeout with correct status and end time',
      () async {
    final sut = fixture.getSut(endTimestampProvider: fixture.endTimestampProvider);
    final transaction = fixture.getTransaction() as SentryTracer;

    await sut.track(transaction, fixture.startTimestamp);

    final ttfdSpan = transaction.children.first;
    expect(transaction.children, hasLength(1));
    expect(ttfdSpan.endTimestamp,
        equals(fixture.endTimestampProvider.endTimestamp));
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
  final hub = Hub(SentryFlutterOptions(dsn: fakeDsn)..tracesSampleRate = 1.0);
  final autoFinishAfter = const Duration(seconds: 2);
  late final endTimestampProvider = FakeTTIDEndTimeStampProvider(startTimestamp);

  ISentrySpan getTransaction({String? name = "Current route"}) {
    return hub.startTransaction(name!, SentrySpanOperations.uiLoad,
        bindToScope: true, startTimestamp: startTimestamp);
  }

  TimeToFullDisplayTracker getSut({EndTimestampProvider? endTimestampProvider}) {
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
