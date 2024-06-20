// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: inference_failure_on_instance_creation

import 'package:collection/collection.dart';
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

  ISentrySpan? _getTTIDSpan(SentryTracer transaction) {
    return transaction.children.firstWhereOrNull((element) =>
        element.context.operation ==
        SentrySpanOperations.uiTimeToInitialDisplay);
  }

  ISentrySpan? _getTTFDSpan(SentryTracer transaction) {
    return transaction.children.firstWhereOrNull((element) =>
        element.context.operation == SentrySpanOperations.uiTimeToFullDisplay);
  }

  group('time to initial display', () {
    group('in root screen app start route', () {
      test('matches startTimestamp of transaction', () async {
        final sut = fixture.getSut();

        final transaction = fixture.getTransaction(name: '/') as SentryTracer;
        await sut.trackRegularRouteTTD(transaction,
            startTimestamp: fixture.startTimestamp);

        final ttidSpan = _getTTIDSpan(transaction);
        expect(transaction, isNotNull);
        expect(transaction.context.operation, SentrySpanOperations.uiLoad);
        expect(transaction.startTimestamp, ttidSpan?.startTimestamp);
      });

      test('finishes ttid span', () async {
        final sut = fixture.getSut();
        final endTimestamp =
            fixture.startTimestamp.add(const Duration(milliseconds: 10));

        final transaction = fixture.getTransaction(name: '/') as SentryTracer;
        await sut.trackAppStartTTD(transaction,
            startTimestamp: fixture.startTimestamp, endTimestamp: endTimestamp);

        final ttidSpan = _getTTIDSpan(transaction);
        expect(ttidSpan?.context.operation,
            SentrySpanOperations.uiTimeToInitialDisplay);
        expect(ttidSpan?.finished, isTrue);
        expect(ttidSpan?.origin, SentryTraceOrigins.autoUiTimeToDisplay);
      });
    });

    group('in regular routes', () {
      test('matches startTimestamp of transaction', () async {
        final sut = fixture.getSut();

        final transaction = fixture.getTransaction() as SentryTracer;
        await sut.trackRegularRouteTTD(transaction,
            startTimestamp: fixture.startTimestamp);

        final ttidSpan = _getTTIDSpan(transaction);
        expect(transaction, isNotNull);
        expect(transaction.context.operation, SentrySpanOperations.uiLoad);
        expect(transaction.startTimestamp, ttidSpan?.startTimestamp);
      });

      group('with approximation strategy', () {
        test('finishes ttid span', () async {
          final sut = fixture.getSut();

          final transaction = fixture.getTransaction() as SentryTracer;
          await sut.trackRegularRouteTTD(transaction,
              startTimestamp: fixture.startTimestamp);

          final ttidSpan = _getTTIDSpan(transaction);
          expect(ttidSpan?.context.operation,
              SentrySpanOperations.uiTimeToInitialDisplay);
          expect(ttidSpan?.finished, isTrue);
          expect(ttidSpan?.origin, SentryTraceOrigins.autoUiTimeToDisplay);
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

          final ttidSpan = _getTTIDSpan(transaction);
          expect(ttidSpan, isNotNull);
          expect(ttidSpan?.finished, isTrue);
          expect(ttidSpan?.origin, SentryTraceOrigins.manualUiTimeToDisplay);
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

    group('in regular routes', () {
      test(
          'finishes span after timeout with deadline exceeded and ttid matching end time',
          () async {
        final sut = fixture.getSut();
        final transaction = fixture.getTransaction() as SentryTracer;

        await sut.trackRegularRouteTTD(transaction,
            startTimestamp: fixture.startTimestamp);

        final ttidSpan = _getTTIDSpan(transaction);
        expect(ttidSpan, isNotNull);

        final ttfdSpan = _getTTFDSpan(transaction);
        expect(ttfdSpan?.finished, isTrue);
        expect(ttfdSpan?.status, SpanStatus.deadlineExceeded());
        expect(ttfdSpan?.endTimestamp, ttidSpan?.endTimestamp);
        expect(ttfdSpan?.startTimestamp, ttidSpan?.startTimestamp);
      });
    });

    group('in root screen app start route', () {
      test(
          'finishes span after timeout with deadline exceeded and ttid matching end time',
          () async {
        final sut = fixture.getSut();
        final transaction =
            fixture.getTransaction(name: 'root ("/")') as SentryTracer;
        final endTimestamp =
            fixture.startTimestamp.add(const Duration(milliseconds: 10));

        await sut.trackAppStartTTD(transaction,
            startTimestamp: fixture.startTimestamp, endTimestamp: endTimestamp);

        final ttidSpan = _getTTIDSpan(transaction);
        expect(ttidSpan, isNotNull);

        final ttfdSpan = _getTTFDSpan(transaction);
        expect(ttfdSpan, isNotNull);

        expect(ttfdSpan?.finished, isTrue);
        expect(ttfdSpan?.status, SpanStatus.deadlineExceeded());
        expect(ttfdSpan?.endTimestamp, ttidSpan?.endTimestamp);
        expect(ttfdSpan?.startTimestamp, ttidSpan?.startTimestamp);
      });
    });

    test('multiple ttfd timeouts have correct ttid matching end time',
        () async {
      final sut = fixture.getSut();
      final transaction = fixture.getTransaction() as SentryTracer;

      // First ttfd timeout
      await sut.trackRegularRouteTTD(transaction,
          startTimestamp: fixture.startTimestamp);

      final ttidSpanA = _getTTIDSpan(transaction);
      expect(ttidSpanA, isNotNull);

      final ttfdSpanA = _getTTFDSpan(transaction);
      expect(ttfdSpanA?.finished, isTrue);
      expect(ttfdSpanA?.status, SpanStatus.deadlineExceeded());
      expect(ttfdSpanA?.endTimestamp, ttidSpanA?.endTimestamp);
      expect(ttfdSpanA?.startTimestamp, ttidSpanA?.startTimestamp);

      // Second ttfd timeout
      await sut.trackRegularRouteTTD(transaction,
          startTimestamp: fixture.startTimestamp);

      final ttidSpanB = _getTTIDSpan(transaction);
      expect(ttidSpanB, isNotNull);

      final ttfdSpanB = _getTTFDSpan(transaction);
      expect(ttfdSpanB?.finished, isTrue);
      expect(ttfdSpanB?.status, SpanStatus.deadlineExceeded());
      expect(ttfdSpanB?.endTimestamp, ttidSpanB?.endTimestamp);
      expect(ttfdSpanB?.startTimestamp, ttidSpanB?.startTimestamp);
    });

    test('does not create ttfd span when not enabled', () async {
      fixture.options.enableTimeToFullDisplayTracing = false;

      final sut = fixture.getSut();

      final transaction = fixture.getTransaction() as SentryTracer;

      await sut.trackRegularRouteTTD(transaction,
          startTimestamp: fixture.startTimestamp);

      final ttfdSpan = transaction.children.firstWhereOrNull((element) =>
          element.context.operation ==
          SentrySpanOperations.uiTimeToFullDisplay);
      expect(ttfdSpan, isNull);
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
  late final endTimeProvider = ttidEndTimestampProvider();
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
      autoFinishAfter: Duration(seconds: 2),
      endTimestampProvider: endTimeProvider,
    );
    return TimeToDisplayTracker(
      ttidTracker: ttidTracker,
      ttfdTracker: ttfdTracker,
      enableTimeToFullDisplayTracing: options.enableTimeToFullDisplayTracing,
    );
  }
}
