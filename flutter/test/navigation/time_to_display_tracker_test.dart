import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/app_start/app_start_tracker.dart';
import 'package:sentry_flutter/src/integrations/integrations.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_transaction_handler.dart';
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

  group('time to initial display', () {
    group('in root screen app start route', () {
      test('startMeasurement finishes ttid span', () async {
        SentryFlutter.native = TestMockSentryNative();
        final sut = fixture.getSut();

        Future.delayed(const Duration(milliseconds: 500), () async {
          AppStartTracker().setAppStartInfo(AppStartInfo(
              DateTime.fromMillisecondsSinceEpoch(0),
              DateTime.fromMillisecondsSinceEpoch(10),
              SentryMeasurement('', 10,
                  unit: DurationSentryMeasurementUnit.milliSecond)));
        });

        await sut.startTracking('/', null);

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
      group('with approximation strategy', () {
        test('startMeasurement finishes ttid span', () async {
          final sut = fixture.getSut();

          await sut.startTracking('Current Route', null);

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
          await sut.startTracking('Current Route', null);

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

  group('time to full display', () {
    setUp(() {
      fixture.options.enableTimeToFullDisplayTracing = true;
    });

    test('startMeasurement creates ttfd and ttid span', () {
      final sut = fixture.getSut();

      return sut.startTracking('Current Route', null).then((value){
        final transaction = fixture.hub.getSpan() as SentryTracer;

        final spans = transaction.children;
        expect(transaction.children, hasLength(2));
        expect(spans[0].context.operation,
            SentrySpanOperations.uiTimeToInitialDisplay);
        expect(
            spans[1].context.operation, SentrySpanOperations.uiTimeToFullDisplay);
      });
    });

    group('in root screen app start route', () {
      test('startMeasurement finishes ttfd span', () async {
        SentryFlutter.native = TestMockSentryNative();
        final sut = fixture.getSut();

        // Simulate app start info being fetched async
        Future.delayed(const Duration(milliseconds: 500), () async {
          AppStartTracker().setAppStartInfo(AppStartInfo(
              DateTime.fromMillisecondsSinceEpoch(0),
              DateTime.fromMillisecondsSinceEpoch(10),
              SentryMeasurement('', 10,
                  unit: DurationSentryMeasurementUnit.milliSecond)));
        });

        await sut.startTracking('/', null);

        final transaction = fixture.hub.getSpan() as SentryTracer;

        final ttfdSpan = transaction.children
            .where((element) =>
                element.context.operation ==
                SentrySpanOperations.uiTimeToFullDisplay)
            .first;
        expect(ttfdSpan, isNotNull);

        await fixture.getSut().reportFullyDisplayed();

        expect(ttfdSpan.finished, isTrue);
      });
    });

    group('in regular routes', () {
      test('finishes ttfd span after calling reportFullyDisplayed', () async {
        final sut = fixture.getSut();

        await sut.startTracking('Current Route', null);

        final transaction = fixture.hub.getSpan() as SentryTracer;

        final ttfdSpan = transaction.children
            .where((element) =>
                element.context.operation ==
                SentrySpanOperations.uiTimeToFullDisplay)
            .first;
        expect(ttfdSpan, isNotNull);

        await fixture.getSut().reportFullyDisplayed();

        expect(ttfdSpan.finished, isTrue);
      });

      test(
          'not using reportFullyDisplayed finishes ttfd span after timeout with deadline exceeded and ttid matching end time',
          () async {
        final sut = fixture.getSut();

        await sut.startTracking('Current Route', null);

        final transaction = fixture.hub.getSpan() as SentryTracer;

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

        await Future.delayed(
            fixture.ttfdAutoFinishAfter + const Duration(milliseconds: 100));

        expect(ttfdSpan.finished, isTrue);
        expect(ttfdSpan.status, SpanStatus.deadlineExceeded());
        expect(ttfdSpan.endTimestamp, ttidSpan.endTimestamp);
      });
    });
  });

  test('screen load tracking creates ui.load transaction', () async {
    final sut = fixture.getSut();

    await sut.startTracking('Current Route', null);

    final transaction = fixture.hub.getSpan();
    expect(transaction, isNotNull);
    expect(transaction?.context.operation, SentrySpanOperations.uiLoad);
  });
}

class Fixture {
  final options = SentryFlutterOptions()
    ..dsn = fakeDsn
    ..tracesSampleRate = 1.0;

  late final hub = Hub(options);

  final frameCallbackHandler = FakeFrameCallbackHandler();
  late final ttidTracker =
      TimeToInitialDisplayTracker(frameCallbackHandler: frameCallbackHandler);

  final ttfdAutoFinishAfter = Duration(milliseconds: 500);
  late final ttfdTracker =
      TimeToFullDisplayTracker(autoFinishAfter: ttfdAutoFinishAfter);

  TimeToDisplayTracker getSut() {
    final enableTimeToFullDisplayTracing =
        options.enableTimeToFullDisplayTracing;

    return TimeToDisplayTracker(
      enableTimeToFullDisplayTracing: enableTimeToFullDisplayTracing,
      ttdTransactionHandler: TimeToDisplayTransactionHandler(
        hub: hub,
        enableAutoTransactions: true,
        autoFinishAfter: const Duration(seconds: 30),
      ),
      ttidTracker: ttidTracker,
      ttfdTracker: ttfdTracker,
    );
  }
}
