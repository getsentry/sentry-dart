// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: inference_failure_on_instance_creation

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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
    fixture.ttidTracker.clear();
  });

  group('time to initial display', () {
    group('in root screen app start route', () {
      test('matches startTimestamp of transaction', () async {
        final sut = fixture.getSut();

        await sut.trackRegularRouteTTD(fixture.getTransaction(name: '/'),
            startTimestamp: fixture.startTimestamp);

        final transaction = fixture.hub.getSpan() as SentryTracer;

        final spans = transaction.children;
        final ttidSpan = spans
            .where((element) =>
                element.context.operation ==
                SentrySpanOperations.uiTimeToInitialDisplay)
            .first;

        expect(transaction, isNotNull);
        expect(transaction.context.operation, SentrySpanOperations.uiLoad);
        expect(transaction.startTimestamp, ttidSpan.startTimestamp);
      });

      test('startMeasurement finishes ttid span', () async {
        SentryFlutter.native = TestMockSentryNative();
        final sut = fixture.getSut();
        final endTimestamp =
            fixture.startTimestamp.add(const Duration(milliseconds: 10));

        await sut.trackAppStartTTD(fixture.getTransaction(name: '/'),
            startTimestamp: fixture.startTimestamp, endTimestamp: endTimestamp);

        await Future.delayed(const Duration(milliseconds: 100));

        final transaction = fixture.hub.getSpan() as SentryTracer;

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

        await sut.trackRegularRouteTTD(fixture.getTransaction(),
            startTimestamp: fixture.startTimestamp);

        final transaction = fixture.hub.getSpan() as SentryTracer;

        final spans = transaction.children;
        final ttidSpan = spans
            .where((element) =>
        element.context.operation ==
            SentrySpanOperations.uiTimeToInitialDisplay)
            .first;

        expect(transaction, isNotNull);
        expect(transaction.context.operation, SentrySpanOperations.uiLoad);
        expect(transaction.startTimestamp, ttidSpan.startTimestamp);
      });

      group('with approximation strategy', () {
        test('startMeasurement finishes ttid span', () async {
          final sut = fixture.getSut();

          await sut.trackRegularRouteTTD(fixture.getTransaction(),
              startTimestamp: fixture.startTimestamp);

          final transaction = fixture.hub.getSpan() as SentryTracer;
          await Future.delayed(const Duration(milliseconds: 2000));

          final spans = transaction.children;
          expect(transaction.children, hasLength(1));
          expect(spans[0].context.operation,
              SentrySpanOperations.uiTimeToInitialDisplay);
          expect(spans[0].finished, isTrue);
        });
      });

      group('with manual strategy', () {
        test('finishes ttid span after reporting with manual api', () async {
          final sut = fixture.getSut();

          Future.delayed(const Duration(milliseconds: 100), () {
            fixture.ttidTracker.markAsManual();
            fixture.ttidTracker.completeTracking();
          });
          await sut.trackRegularRouteTTD(fixture.getTransaction(),
              startTimestamp: fixture.startTimestamp);

          final transaction = fixture.hub.getSpan() as SentryTracer;

          await Future.delayed(const Duration(milliseconds: 100));

          final ttidSpan = transaction.children
              .where((element) =>
                  element.context.operation ==
                  SentrySpanOperations.uiTimeToInitialDisplay)
              .first;
          expect(ttidSpan, isNotNull);

          await Future.delayed(const Duration(milliseconds: 100));

          expect(ttidSpan.finished, isTrue);
        });
      });
    });
  });

  test('screen load tracking creates ui.load transaction', () async {
    final sut = fixture.getSut();
    final startTimestamp =
        getUtcDateTime().add(const Duration(milliseconds: 100));

    await sut.trackRegularRouteTTD(fixture.getTransaction(),
        startTimestamp: startTimestamp);

    final transaction = fixture.hub.getSpan();
    expect(transaction, isNotNull);
    expect(transaction?.context.operation, SentrySpanOperations.uiLoad);
  });
}

class Fixture {
  final startTimestamp = getUtcDateTime();
  final options = SentryFlutterOptions()
    ..dsn = fakeDsn
    ..tracesSampleRate = 1.0;

  late final hub = Hub(options);

  final frameCallbackHandler = FakeFrameCallbackHandler();
  late final ttidTracker =
      TimeToInitialDisplayTracker(frameCallbackHandler: frameCallbackHandler);

  ISentrySpan getTransaction({String? name = "Current route"}) {
    return hub.startTransaction(name!, 'ui.load',
        bindToScope: true, startTimestamp: startTimestamp);
  }

  TimeToDisplayTracker getSut() {
    return TimeToDisplayTracker(
      ttidTracker: ttidTracker,
    );
  }
}
