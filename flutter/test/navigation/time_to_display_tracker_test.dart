import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/navigation/display_strategy_evaluator.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker.dart';
import 'package:sentry/src/sentry_tracer.dart';

import '../mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    fixture = Fixture();
  });

  group('time to initial display', () {
    group('in root screen app start route', () {});

    group('in regular routes', () {
      test('startMeasurement creates ttid span', () async {
        final sut = fixture.getSut();

        sut.startMeasurement('Current Route', null);

        final transaction = fixture.hub.getSpan() as SentryTracer;
        await Future.delayed(const Duration(milliseconds: 100));

        final spans = transaction.children;
        expect(transaction.children, hasLength(1));
        expect(spans[0].context.operation,
            SentryTraceOrigins.uiTimeToInitialDisplay);
      });

      group('with approximation strategy', () {});

      group('with manual strategy', () {
        test('finishes ttid span after reporting with manual api', () async {
          final sut = fixture.getSut();

          sut.startMeasurement('Current Route', null);

          final transaction = fixture.hub.getSpan() as SentryTracer;
          await Future.delayed(const Duration(milliseconds: 100));

          final ttidSpan = transaction.children
              .where((element) =>
                  element.context.operation ==
                  SentryTraceOrigins.uiTimeToInitialDisplay)
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

    test('startMeasurement creates ttfd and ttid span', () async {
      final sut = fixture.getSut(enableTimeToFullDisplayTracing: true);

      sut.startMeasurement('Current Route', null);

      final transaction = fixture.hub.getSpan() as SentryTracer;
      await Future.delayed(const Duration(milliseconds: 100));

      final spans = transaction.children;
      expect(transaction.children, hasLength(2));
      expect(spans[0].context.operation,
          SentryTraceOrigins.uiTimeToInitialDisplay);
      expect(
          spans[1].context.operation, SentryTraceOrigins.uiTimeToFullDisplay);
    });

    group('in root screen app start route', () {});
    group('in regular routes', () {
      test('finishes ttfd span after calling reportFullyDisplayed', () async {
        final sut = fixture.getSut();

        sut.startMeasurement('Current Route', null);

        final transaction = fixture.hub.getSpan() as SentryTracer;
        await Future.delayed(const Duration(milliseconds: 100));

        final ttfdSpan = transaction.children
            .where((element) =>
                element.context.operation ==
                SentryTraceOrigins.uiTimeToFullDisplay)
            .first;
        expect(ttfdSpan, isNotNull);

        SentryFlutter.reportFullyDisplayed();
        await Future.delayed(const Duration(milliseconds: 100));

        expect(ttfdSpan.finished, isTrue);
      });

      test(
          'not using reportFullyDisplayed finishes ttfd span after timeout with deadline exceeded',
          () async {
        final sut = fixture.getSut();
        sut.ttfdAutoFinishAfter = const Duration(seconds: 3);

        sut.startMeasurement('Current Route', null);

        final transaction = fixture.hub.getSpan() as SentryTracer;
        await Future.delayed(const Duration(milliseconds: 100));
        DisplayStrategyEvaluator().reportManual('Current Route');

        final ttfdSpan = transaction.children
            .where((element) =>
                element.context.operation ==
                SentryTraceOrigins.uiTimeToFullDisplay)
            .first;
        expect(ttfdSpan, isNotNull);

        await Future.delayed(sut.ttfdAutoFinishAfter + const Duration(milliseconds: 100));

        expect(ttfdSpan.finished, isTrue);
        expect(ttfdSpan.status, SpanStatus.deadlineExceeded());
      });
    });
  });

  test('screen load tracking creates ui.load transaction', () async {
    final sut = fixture.getSut();

    sut.startMeasurement('Current Route', null);

    final transaction = fixture.hub.getSpan();
    expect(transaction, isNotNull);
    expect(transaction?.context.operation, SentryTraceOrigins.uiLoad);
  });
}

class Fixture {
  final options = SentryFlutterOptions()
    ..dsn = fakeDsn
    ..tracesSampleRate = 1.0;

  late final hub = Hub(options);

  TimeToDisplayTracker getSut({bool enableTimeToFullDisplayTracing = false}) {
    return TimeToDisplayTracker(
      hub: hub,
      enableAutoTransactions: true,
      autoFinishAfter: const Duration(seconds: 3),
    );
  }
}
