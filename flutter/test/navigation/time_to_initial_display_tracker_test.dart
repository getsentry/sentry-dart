// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/navigation/time_to_initial_display_tracker.dart';

import '../fake_frame_callback_handler.dart';
import '../mocks.dart';
import 'package:sentry/src/sentry_tracer.dart';

void main() {
  late Fixture fixture;
  late TimeToInitialDisplayTracker sut;

  setUp(() {
    fixture = Fixture();
    sut = fixture.getSut();
  });

  tearDown(() {
    sut.clear();
  });

  group('app start', () {
    test('tracking creates and finishes ttid span with correct measurements',
        () async {
      final transaction =
          fixture.getTransaction(name: 'root ("/")') as SentryTracer;
      final endTimestamp =
          fixture.startTimestamp.add(const Duration(milliseconds: 10));

      await sut.trackAppStart(transaction,
          startTimestamp: fixture.startTimestamp, endTimestamp: endTimestamp);

      final children = transaction.children;
      expect(children, hasLength(1));

      final ttidSpan = children.first;
      expect(ttidSpan.context.operation,
          SentrySpanOperations.uiTimeToInitialDisplay);
      expect(ttidSpan.finished, isTrue);
      expect(ttidSpan.context.description, 'root ("/") initial display');
      expect(ttidSpan.origin, SentryTraceOrigins.autoUiTimeToDisplay);

      final ttidMeasurement =
          transaction.measurements['time_to_initial_display'];
      expect(ttidMeasurement, isNotNull);
      expect(ttidMeasurement?.unit, DurationSentryMeasurementUnit.milliSecond);
      expect(ttidMeasurement?.value, 10);
    });
  });

  group('regular route', () {
    test(
        'approximation tracking creates and finishes ttid span with correct measurements',
        () async {
      final transaction = fixture.getTransaction() as SentryTracer;

      await sut.trackRegularRoute(transaction, fixture.startTimestamp);

      final children = transaction.children;
      expect(children, hasLength(1));

      final ttidSpan = children.first;
      expect(ttidSpan.context.operation,
          SentrySpanOperations.uiTimeToInitialDisplay);
      expect(ttidSpan.finished, isTrue);
      expect(ttidSpan.context.description, 'Regular route initial display');
      expect(ttidSpan.origin, SentryTraceOrigins.autoUiTimeToDisplay);

      final ttidMeasurement =
          transaction.measurements['time_to_initial_display'];
      expect(ttidMeasurement, isNotNull);
      expect(ttidMeasurement?.unit, DurationSentryMeasurementUnit.milliSecond);
      expect(
          ttidMeasurement?.value,
          greaterThanOrEqualTo(
              fixture.finishFrameAfterDuration.inMilliseconds));
    });

    test(
        'manual tracking creates and finishes ttid span with correct measurements',
        () async {
      final transaction = fixture.getTransaction() as SentryTracer;

      sut.markAsManual();
      Future.delayed(fixture.finishFrameAfterDuration, () {
        sut.completeTracking();
      });
      await sut.trackRegularRoute(transaction, fixture.startTimestamp);

      final children = transaction.children;
      expect(children, hasLength(1));

      final ttidSpan = children.first;
      expect(ttidSpan.context.operation,
          SentrySpanOperations.uiTimeToInitialDisplay);
      expect(ttidSpan.finished, isTrue);
      expect(ttidSpan.context.description, 'Regular route initial display');
      expect(ttidSpan.origin, SentryTraceOrigins.manualUiTimeToDisplay);
      final ttidMeasurement =
          transaction.measurements['time_to_initial_display'];
      expect(ttidMeasurement, isNotNull);
      expect(ttidMeasurement?.unit, DurationSentryMeasurementUnit.milliSecond);
      expect(
          ttidMeasurement?.value,
          greaterThanOrEqualTo(
              fixture.finishFrameAfterDuration.inMilliseconds));
    });
  });

  group('determineEndtime', () {
    test('can complete automatically in approximation mode', () async {
      final futureEndTime = sut.determineEndTime();

      expect(futureEndTime, completes);
    });

    test('prevents automatic completion in manual mode', () async {
      sut.markAsManual();
      final futureEndTime = sut.determineEndTime();

      expect(futureEndTime, doesNotComplete);
    });

    test('can complete manually in manual mode', () async {
      sut.markAsManual();
      final futureEndTime = sut.determineEndTime();

      sut.completeTracking();
      expect(futureEndTime, completes);
    });

    test('returns the correct approximation end time', () async {
      final futureEndTime = sut.determineEndTime();

      final endTime = await futureEndTime;
      expect(endTime?.difference(fixture.startTimestamp).inSeconds,
          fixture.finishFrameAfterDuration.inSeconds);
    });

    test('returns the correct manual end time', () async {
      sut.markAsManual();
      final futureEndTime = sut.determineEndTime();

      Future.delayed(fixture.finishFrameAfterDuration, () {
        sut.completeTracking();
      });

      final endTime = await futureEndTime;
      expect(endTime?.difference(fixture.startTimestamp).inSeconds,
          fixture.finishFrameAfterDuration.inSeconds);
    });
  });
}

class Fixture {
  final startTimestamp = getUtcDateTime();
  final hub = Hub(SentryFlutterOptions(dsn: fakeDsn)..tracesSampleRate = 1.0);
  final finishFrameAfterDuration = Duration(milliseconds: 100);
  late final fakeFrameCallbackHandler =
      FakeFrameCallbackHandler(finishAfterDuration: finishFrameAfterDuration);

  ISentrySpan getTransaction({String? name = "Regular route"}) {
    return hub.startTransaction(name!, 'ui.load',
        bindToScope: true, startTimestamp: startTimestamp);
  }

  TimeToInitialDisplayTracker getSut() {
    return TimeToInitialDisplayTracker(
        frameCallbackHandler: fakeFrameCallbackHandler);
  }
}
