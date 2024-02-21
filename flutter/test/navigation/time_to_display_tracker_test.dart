import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/integrations.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker.dart';
import 'package:sentry/src/sentry_tracer.dart';

import '../fake_frame_callback_handler.dart';
import '../mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    fixture = Fixture();
  });

  tearDown(() async {
    await Future.delayed(const Duration(milliseconds: 500));
  });

  group('time to initial display', () {
    group('in root screen app start route', () {
      test('startMeasurement finishes ttid span', () async {
        SentryFlutter.native = TestMockSentryNative();
        final sut = fixture.getSut();

        sut.startMeasurement('/', null);

        AppStartTracker().setAppStartInfo(AppStartInfo(
            DateTime.fromMillisecondsSinceEpoch(0),
            DateTime.fromMillisecondsSinceEpoch(10),
            SentryMeasurement('', 0)));

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

          sut.startMeasurement('Current Route', null);

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

          sut.startMeasurement('Current Route', null);

          final transaction = fixture.hub.getSpan() as SentryTracer;

          await Future.delayed(const Duration(milliseconds: 100));

          // SentryFlutter.reportInitiallyDisplayed(routeName: 'Current Route');

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

    test('startMeasurement creates ttfd and ttid span', () async {
      final sut = fixture.getSut();

      sut.startMeasurement('Current Route', null);

      final transaction = fixture.hub.getSpan() as SentryTracer;
      await Future.delayed(const Duration(milliseconds: 100));

      final spans = transaction.children;
      expect(transaction.children, hasLength(2));
      expect(spans[0].context.operation,
          SentrySpanOperations.uiTimeToInitialDisplay);
      expect(
          spans[1].context.operation, SentrySpanOperations.uiTimeToFullDisplay);
    });

    group('in root screen app start route', () {
      test('startMeasurement finishes ttfd span', () async {
        SentryFlutter.native = TestMockSentryNative();
        final sut = fixture.getSut();

        sut.startMeasurement('/', null);

        AppStartTracker().setAppStartInfo(AppStartInfo(
            DateTime.fromMillisecondsSinceEpoch(0),
            DateTime.fromMillisecondsSinceEpoch(10),
            SentryMeasurement('', 10,
                unit: DurationSentryMeasurementUnit.milliSecond)));

        await Future.delayed(const Duration(milliseconds: 100));

        final transaction = fixture.hub.getSpan() as SentryTracer;

        final ttfdSpan = transaction.children
            .where((element) =>
                element.context.operation ==
                SentrySpanOperations.uiTimeToFullDisplay)
            .first;
        expect(ttfdSpan, isNotNull);

        SentryFlutter.reportFullyDisplayed();

        await Future.delayed(const Duration(milliseconds: 100));

        expect(ttfdSpan.finished, isTrue);
      });
    });

    group('in regular routes', () {
      test('finishes ttfd span after calling reportFullyDisplayed', () async {
        final sut = fixture.getSut();

        sut.startMeasurement('Current Route', null);

        final transaction = fixture.hub.getSpan() as SentryTracer;
        await Future.delayed(const Duration(milliseconds: 100));

        final ttfdSpan = transaction.children
            .where((element) =>
                element.context.operation ==
                SentrySpanOperations.uiTimeToFullDisplay)
            .first;
        expect(ttfdSpan, isNotNull);

        SentryFlutter.reportFullyDisplayed();
        await Future.delayed(const Duration(milliseconds: 100));

        expect(ttfdSpan.finished, isTrue);
      });

      test(
          'not using reportFullyDisplayed finishes ttfd span after timeout with deadline exceeded and ttid matching end time',
          () async {
        final sut = fixture.getSut();
        sut.ttfdAutoFinishAfter = const Duration(seconds: 3);

        sut.startMeasurement('Current Route', null);

        final transaction = fixture.hub.getSpan() as SentryTracer;

        await Future.delayed(const Duration(milliseconds: 100));

        final ttfdSpan = transaction.children
            .where((element) =>
                element.context.operation ==
                SentrySpanOperations.uiTimeToFullDisplay)
            .first;
        expect(ttfdSpan, isNotNull);

        final ttidSpan = transaction.children
            .where((element) =>
                element.context.operation ==
                SentrySpanOperations.uiTimeToInitialDisplay)
            .first;
        expect(ttfdSpan, isNotNull);

        await Future.delayed(
            sut.ttfdAutoFinishAfter + const Duration(milliseconds: 100));

        expect(ttfdSpan.finished, isTrue);
        expect(ttfdSpan.status, SpanStatus.deadlineExceeded());
        expect(ttfdSpan.endTimestamp, ttidSpan.endTimestamp);
      });
    });
  });

  test('screen load tracking creates ui.load transaction', () async {
    final sut = fixture.getSut();

    sut.startMeasurement('Current Route', null);

    final transaction = fixture.hub.getSpan();
    expect(transaction, isNotNull);
    expect(transaction?.context.operation, SentrySpanOperations.uiLoad);
  });
}

class Fixture {
  final options = SentryFlutterOptions()
    ..dsn = fakeDsn
    ..tracesSampleRate = 1.0;

  final frameCallbackHandler = FakeFrameCallbackHandler();

  late final hub = Hub(options);

  TimeToDisplayTracker getSut({bool enableTimeToFullDisplayTracing = false}) {
    return TimeToDisplayTracker(
      hub: hub,
      enableAutoTransactions: true,
      autoFinishAfter: const Duration(seconds: 3),
      frameCallbackHandler: frameCallbackHandler,
    );
  }
}
