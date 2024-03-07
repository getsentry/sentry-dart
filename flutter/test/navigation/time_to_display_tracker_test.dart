// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: inference_failure_on_instance_creation

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/frame_callback_handler.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_flutter/src/navigation/time_to_full_display_tracker.dart';
import 'package:sentry_flutter/src/navigation/time_to_initial_display_tracker.dart';

import '../fake_frame_callback_handler.dart';
import '../mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    fixture = Fixture();
  });

  tearDown(() {
    fixture.ttidTracker?.clear();
  });

  group('time to initial display', () {
    group('in root screen app start route', () {
      test('matches startTimestamp of transaction', () async {
        final sut = fixture.getSut();

        final transaction = fixture.getTransaction(name: '/') as SentryTracer;
        await sut.trackRegularRouteTTD(transaction,
            startTimestamp: fixture.startTimestamp);

        final ttidSpan = transaction.children
            .where((element) =>
                element.context.operation ==
                SentrySpanOperations.uiTimeToInitialDisplay)
            .first;
        expect(transaction, isNotNull);
        expect(transaction.context.operation, SentrySpanOperations.uiLoad);
        expect(transaction.startTimestamp, ttidSpan.startTimestamp);
      });

      test('finishes ttid span', () async {
        SentryFlutter.native = TestMockSentryNative();
        final sut = fixture.getSut();
        final endTimestamp =
            fixture.startTimestamp.add(const Duration(milliseconds: 10));

        final transaction = fixture.getTransaction(name: '/') as SentryTracer;
        await sut.trackAppStartTTD(transaction,
            startTimestamp: fixture.startTimestamp, endTimestamp: endTimestamp);

        final ttidSpan = transaction.children
            .where((element) =>
                element.context.operation ==
                SentrySpanOperations.uiTimeToInitialDisplay)
            .first;
        expect(ttidSpan.context.operation,
            SentrySpanOperations.uiTimeToInitialDisplay);
        expect(ttidSpan.finished, isTrue);
        expect(ttidSpan.origin, SentryTraceOrigins.autoUiTimeToDisplay);
      });
    });

    group('in regular routes', () {
      test('matches startTimestamp of transaction', () async {
        final sut = fixture.getSut();

        final transaction = fixture.getTransaction() as SentryTracer;
        await sut.trackRegularRouteTTD(transaction,
            startTimestamp: fixture.startTimestamp);

        final ttidSpan = transaction.children
            .where((element) =>
                element.context.operation ==
                SentrySpanOperations.uiTimeToInitialDisplay)
            .first;
        expect(transaction, isNotNull);
        expect(transaction.context.operation, SentrySpanOperations.uiLoad);
        expect(transaction.startTimestamp, ttidSpan.startTimestamp);
      });

      group('with approximation strategy', () {
        test('finishes ttid span', () async {
          final sut = fixture.getSut();

          final transaction = fixture.getTransaction() as SentryTracer;
          await sut.trackRegularRouteTTD(transaction,
              startTimestamp: fixture.startTimestamp);

          final ttidSpan = transaction.children
              .where((element) =>
                  element.context.operation ==
                  SentrySpanOperations.uiTimeToInitialDisplay)
              .first;
          expect(ttidSpan.context.operation,
              SentrySpanOperations.uiTimeToInitialDisplay);
          expect(ttidSpan.finished, isTrue);
          expect(ttidSpan.origin, SentryTraceOrigins.autoUiTimeToDisplay);
        });

        test('completes with timeout when not completing the tracking',
            () async {
          final sut = fixture.getSut(triggerApproximationTimeout: true);

          final transaction = fixture.getTransaction() as SentryTracer;
          await sut.trackRegularRouteTTD(transaction,
              startTimestamp: fixture.startTimestamp);
        });
      });

      group('with manual strategy', () {
        test('finishes ttid span', () async {
          final sut = fixture.getSut();

          Future.delayed(const Duration(milliseconds: 1), () {
            fixture.ttidTracker?.markAsManual();
            fixture.ttidTracker?.completeTracking();
          });
          final transaction = fixture.getTransaction() as SentryTracer;
          await sut.trackRegularRouteTTD(transaction,
              startTimestamp: fixture.startTimestamp);

          final ttidSpan = transaction.children
              .where((element) =>
                  element.context.operation ==
                  SentrySpanOperations.uiTimeToInitialDisplay)
              .first;
          expect(ttidSpan, isNotNull);
          expect(ttidSpan.finished, isTrue);
          expect(ttidSpan.origin, SentryTraceOrigins.manualUiTimeToDisplay);
        });

        test('completes with timeout when not completing the tracking',
            () async {
          final sut = fixture.getSut();

          fixture.ttidTracker?.markAsManual();
          // Not calling completeTracking() triggers the manual timeout

          final transaction = fixture.getTransaction() as SentryTracer;
          await sut.trackRegularRouteTTD(transaction,
              startTimestamp: fixture.startTimestamp);
        });
      });
    });
  });

  group('time to full display', () {
    setUp(() {
      fixture.options.enableTimeToFullDisplayTracing = true;
    });

    group('in root screen app start route', () {
      test('tracking waits for ttfd span to finish with timeout', () async {
        SentryFlutter.native = TestMockSentryNative();
        final sut = fixture.getSut(triggerApproximationTimeout: true);

        final transaction =
            fixture.getTransaction(name: 'root: ("/")') as SentryTracer;
        final endTimestamp =
            fixture.startTimestamp.add(const Duration(milliseconds: 10));

        await sut.trackAppStartTTD(transaction,
            startTimestamp: fixture.startTimestamp, endTimestamp: endTimestamp);

        final ttfdSpan = transaction.children
            .where((element) =>
                element.context.operation ==
                SentrySpanOperations.uiTimeToFullDisplay)
            .first;
        expect(ttfdSpan, isNotNull);
        expect(ttfdSpan.finished, isTrue);
        expect(ttfdSpan.status, SpanStatus.deadlineExceeded());
      });

      test('tracking waits for ttfd span to finish with reportFullyDisplayed()',
          () async {
        SentryFlutter.native = TestMockSentryNative();
        final sut = fixture.getSut();

        final transaction =
            fixture.getTransaction(name: 'root: ("/")') as SentryTracer;
        final endTimestamp =
            fixture.startTimestamp.add(const Duration(milliseconds: 10));

        Future.delayed(const Duration(milliseconds: 100), () {
          sut.reportFullyDisplayed();
        });

        await sut.trackAppStartTTD(transaction,
            startTimestamp: fixture.startTimestamp, endTimestamp: endTimestamp);

        final ttfdSpan = transaction.children
            .where((element) =>
                element.context.operation ==
                SentrySpanOperations.uiTimeToFullDisplay)
            .first;
        expect(ttfdSpan, isNotNull);
        expect(ttfdSpan.finished, isTrue);
        expect(ttfdSpan.status, SpanStatus.ok());
      });
    });

    group('in regular routes', () {
      test('finishes ttfd span after calling reportFullyDisplayed', () async {
        final sut = fixture.getSut();
        final transaction = fixture.getTransaction() as SentryTracer;

        Future.delayed(const Duration(milliseconds: 100), () {
          sut.reportFullyDisplayed();
        });

        await sut.trackRegularRouteTTD(transaction,
            startTimestamp: fixture.startTimestamp);

        final ttfdSpan = transaction.children
            .where((element) =>
                element.context.operation ==
                SentrySpanOperations.uiTimeToFullDisplay)
            .first;
        expect(ttfdSpan, isNotNull);

        expect(ttfdSpan.finished, isTrue);
        expect(ttfdSpan.status, SpanStatus.ok());
      });

      test(
          'not using reportFullyDisplayed finishes ttfd span after timeout with deadline exceeded and ttid matching end time',
          () async {
        final sut = fixture.getSut();
        final transaction = fixture.getTransaction() as SentryTracer;

        await sut.trackRegularRouteTTD(transaction,
            startTimestamp: fixture.startTimestamp);

        final ttidSpan = transaction.children
            .where((element) =>
                element.context.operation ==
                SentrySpanOperations.uiTimeToInitialDisplay)
            .first;
        expect(ttidSpan, isNotNull);

        final ttfdSpan = transaction.children
            .where((element) =>
                element.context.operation ==
                SentrySpanOperations.uiTimeToFullDisplay)
            .first;
        expect(ttfdSpan, isNotNull);

        expect(ttfdSpan.finished, isTrue);
        expect(ttfdSpan.status, SpanStatus.deadlineExceeded());
        expect(ttfdSpan.endTimestamp, ttidSpan.endTimestamp);
        expect(ttfdSpan.startTimestamp, ttidSpan.startTimestamp);
      });
    });
  });

  test('screen load tracking creates ui.load transaction', () async {
    final sut = fixture.getSut();

    final transaction = fixture.getTransaction() as SentryTracer;
    await sut.trackRegularRouteTTD(transaction,
        startTimestamp: fixture.startTimestamp);

    expect(transaction, isNotNull);
    expect(transaction.context.operation, SentrySpanOperations.uiLoad);
  });
}

class Fixture {
  final startTimestamp = getUtcDateTime();
  final options = SentryFlutterOptions()
    ..dsn = fakeDsn
    ..tracesSampleRate = 1.0;
  late final endTimeProvider = TTIDEndTimestampProvider();
  late final hub = Hub(options);

  TimeToInitialDisplayTracker? ttidTracker;
  TimeToFullDisplayTracker? ttfdTracker;

  ISentrySpan getTransaction({String? name = "Current route"}) {
    return hub.startTransaction(name!, 'ui.load',
        startTimestamp: startTimestamp);
  }

  TimeToDisplayTracker getSut({bool triggerApproximationTimeout = false}) {
    ttidTracker = TimeToInitialDisplayTracker(
        frameCallbackHandler: triggerApproximationTimeout
            ? DefaultFrameCallbackHandler()
            : FakeFrameCallbackHandler());
    ttfdTracker = TimeToFullDisplayTracker(
      autoFinishAfter: Duration(seconds: 5),
      endTimestampProvider: endTimeProvider,
    );
    return TimeToDisplayTracker(
      ttidTracker: ttidTracker,
      ttfdTracker: ttfdTracker,
      enableTimeToFullDisplayTracing: options.enableTimeToFullDisplayTracing,
    );
  }
}
