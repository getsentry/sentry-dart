// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: inference_failure_on_instance_creation

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/frame_callback_handler.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker.dart';
import 'package:sentry/src/sentry_tracer.dart';
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

      test('trackAppStartTTD finishes ttid span', () async {
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

      test('trackRegularRoute finishes ttid span', () async {
        SentryFlutter.native = TestMockSentryNative();
        final sut = fixture.getSut();

        final transaction = fixture.getTransaction() as SentryTracer;
        await sut.trackRegularRouteTTD(transaction,
            startTimestamp: fixture.startTimestamp);

        final spans = transaction.children;
        expect(transaction.children, hasLength(1));
        expect(spans[0].context.operation,
            SentrySpanOperations.uiTimeToInitialDisplay);
        expect(spans[0].finished, isTrue);
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
        test('trackRegularRouteTTD finishes ttid span', () async {
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

        test('timeout triggered when not completing the tracking', () async {
          final sut = fixture.getSut(triggerApproximationTimeout: true);

          final transaction = fixture.getTransaction() as SentryTracer;
          await sut.trackRegularRouteTTD(transaction,
              startTimestamp: fixture.startTimestamp);

          expect(transaction.children, hasLength(0));
        });
      });

      group('with manual strategy', () {
        test('finishes ttid span after reporting with manual api', () async {
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

        test('timeout triggered when not completing the tracking', () async {
          final sut = fixture.getSut();

          fixture.ttidTracker?.markAsManual();
          // Not calling completeTracking() triggers the manual timeout

          final transaction = fixture.getTransaction() as SentryTracer;
          await sut.trackRegularRouteTTD(transaction,
              startTimestamp: fixture.startTimestamp);

          expect(transaction.children, hasLength(0));
        });
      });
    });
  });

  test('screen load tracking creates ui.load transaction', () async {
    final sut = fixture.getSut();
    final startTimestamp =
        getUtcDateTime().add(const Duration(milliseconds: 100));

    final transaction = fixture.getTransaction() as SentryTracer;
    await sut.trackRegularRouteTTD(transaction, startTimestamp: startTimestamp);

    expect(transaction, isNotNull);
    expect(transaction.context.operation, SentrySpanOperations.uiLoad);
  });
}

class Fixture {
  final startTimestamp = getUtcDateTime();
  final options = SentryFlutterOptions()
    ..dsn = fakeDsn
    ..tracesSampleRate = 1.0;

  late final hub = Hub(options);
  TimeToInitialDisplayTracker? ttidTracker;

  ISentrySpan getTransaction({String? name = "Current route"}) {
    return hub.startTransaction(name!, 'ui.load',
        bindToScope: true, startTimestamp: startTimestamp);
  }

  TimeToDisplayTracker getSut({bool triggerApproximationTimeout = false}) {
    ttidTracker = TimeToInitialDisplayTracker(
        frameCallbackHandler: triggerApproximationTimeout
            ? DefaultFrameCallbackHandler()
            : FakeFrameCallbackHandler());
    return TimeToDisplayTracker(
      ttidTracker: ttidTracker,
    );
  }
}
