// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/frame_callback_handler.dart';
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
      final endTimestamp =
          fixture.startTimestamp.add(const Duration(milliseconds: 10));

      final transaction =
          fixture.getTransaction(name: 'root ("/")') as SentryTracer;
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
      expect(ttidSpan.startTimestamp, fixture.startTimestamp);
      expect(ttidSpan.endTimestamp, endTimestamp);

      final ttidMeasurement =
          transaction.measurements['time_to_initial_display'];
      expect(ttidMeasurement, isNotNull);
      expect(ttidMeasurement?.unit, DurationSentryMeasurementUnit.milliSecond);
      expect(
          ttidMeasurement?.value,
          ttidSpan.endTimestamp!
              .difference(ttidSpan.startTimestamp)
              .inMilliseconds);
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
      expect(ttidMeasurement?.value,
          greaterThanOrEqualTo(fixture.finishFrameDuration.inMilliseconds));
      expect(
          ttidMeasurement?.value,
          ttidSpan.endTimestamp!
              .difference(ttidSpan.startTimestamp)
              .inMilliseconds);
    });

    test(
        'manual tracking creates and finishes ttid span with correct measurements',
        () async {
      sut.markAsManual();
      Future.delayed(fixture.finishFrameDuration, () {
        sut.completeTracking();
      });

      final transaction = fixture.getTransaction() as SentryTracer;
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
      expect(ttidMeasurement?.value,
          greaterThanOrEqualTo(fixture.finishFrameDuration.inMilliseconds));
      expect(
          ttidMeasurement?.value,
          ttidSpan.endTimestamp!
              .difference(ttidSpan.startTimestamp)
              .inMilliseconds);
    });
  });

  group('determineEndtime', () {
    test('can complete as null in approximation mode with timeout', () async {
      final futureEndTime = await fixture
          .getSut(triggerApproximationTimeout: true)
          .determineEndTime();

      expect(futureEndTime, null);
    });

    test('can complete as null in manual mode with timeout', () async {
      final sut = fixture.getSut();
      sut.markAsManual();
      // Not calling completeTracking() triggers the manual timeout

      final futureEndTime = await sut.determineEndTime();

      expect(futureEndTime, null);
    });

    test('can complete automatically in approximation mode', () async {
      final futureEndTime = await sut.determineEndTime();

      expect(futureEndTime, isNotNull);
    });

    test('can complete manually in manual mode', () async {
      sut.markAsManual();
      Future<void>.delayed(Duration(milliseconds: 1), () {
        sut.completeTracking();
      });
      final futureEndTime = await sut.determineEndTime();

      expect(futureEndTime, isNotNull);
    });

    test('returns the correct approximation end time', () async {
      final endTme = await sut.determineEndTime();

      expect(endTme?.difference(fixture.startTimestamp).inSeconds,
          fixture.finishFrameDuration.inSeconds);
    });

    test('returns the correct manual end time', () async {
      sut.markAsManual();
      Future.delayed(fixture.finishFrameDuration, () {
        sut.completeTracking();
      });

      final endTime = await sut.determineEndTime();

      expect(endTime?.difference(fixture.startTimestamp).inSeconds,
          fixture.finishFrameDuration.inSeconds);
    });
  });
}

class Fixture {
  final startTimestamp = getUtcDateTime();
  final hub = Hub(SentryFlutterOptions(dsn: fakeDsn)..tracesSampleRate = 1.0);
  late final fakeFrameCallbackHandler = FakeFrameCallbackHandler();

  ISentrySpan getTransaction({String? name = "Regular route"}) {
    return hub.startTransaction(name!, 'ui.load',
        bindToScope: true, startTimestamp: startTimestamp);
  }

  /// The time it takes until a fake frame has been triggered
  Duration get finishFrameDuration =>
      fakeFrameCallbackHandler.finishAfterDuration;

  TimeToInitialDisplayTracker getSut(
      {bool triggerApproximationTimeout = false}) {
    return TimeToInitialDisplayTracker(
        frameCallbackHandler: triggerApproximationTimeout
            ? DefaultFrameCallbackHandler()
            : FakeFrameCallbackHandler());
  }
}
