// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/frame_callback_handler.dart';
import 'package:sentry_flutter/src/navigation/time_to_initial_display_tracker.dart';

import '../fake_frame_callback_handler.dart';
import '../mocks.dart';

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

  group('track', () {
    test(
        'approximation tracking creates and finishes ttid span with correct measurements',
        () async {
      final transaction = fixture.getTransaction() as SentryTracer;
      await sut.track(
        transaction: transaction,
        startTimestamp: fixture.startTimestamp,
      );

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

    test('starting after completing still finished correctly', () async {
      await Future.delayed(fixture.finishFrameDuration, () {
        sut.completeTracking();
      });

      final transaction = fixture.getTransaction() as SentryTracer;
      await sut.track(
        transaction: transaction,
        startTimestamp: fixture.startTimestamp,
      );

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

    test('providing endTimestamp finishes transaction with it', () async {
      final transaction = fixture.getTransaction() as SentryTracer;
      final endTimestamp =
          fixture.startTimestamp.add(Duration(milliseconds: 100));

      await sut.track(
        transaction: transaction,
        startTimestamp: fixture.startTimestamp,
        endTimestamp: endTimestamp,
      );

      final children = transaction.children;
      expect(children, hasLength(1));

      final ttidSpan = transaction.children.first;
      expect(endTimestamp, ttidSpan.endTimestamp);

      final ttidMeasurement =
          transaction.measurements['time_to_initial_display'];

      expect(ttidMeasurement, isNotNull);
      expect(ttidMeasurement?.unit, DurationSentryMeasurementUnit.milliSecond);
      expect(ttidMeasurement?.value, greaterThanOrEqualTo(100));
    });

    test('providing endTimestamp sets endTimestamp ivar', () async {
      final transaction = fixture.getTransaction() as SentryTracer;
      final endTimestamp = fixture.startTimestamp.add(Duration(seconds: 1));

      await sut.track(
        transaction: transaction,
        startTimestamp: fixture.startTimestamp,
        endTimestamp: endTimestamp,
      );

      expect(sut.endTimestamp, endTimestamp);
    });
  });

  group('determineEndtime', () {
    test('can complete as null in approximation mode with timeout', () async {
      final futureEndTime = await fixture
          .getSut(triggerApproximationTimeout: true)
          .determineEndTime();

      expect(futureEndTime, null);
    });

    test('can complete automatically in approximation mode', () async {
      final futureEndTime = await sut.determineEndTime();

      expect(futureEndTime, isNotNull);
    });

    test('returns the correct approximation end time', () async {
      final endTme = await sut.determineEndTime();

      expect(endTme?.difference(fixture.startTimestamp).inSeconds,
          fixture.finishFrameDuration.inSeconds);
    });
  });
}

class Fixture {
  final startTimestamp = getUtcDateTime();
  final hub = Hub(defaultTestOptions()..tracesSampleRate = 1.0);
  final fakeFrameCallbackHandler = FakeFrameCallbackHandler();

  ISentrySpan getTransaction({String? name = "Regular route"}) {
    return hub.startTransaction(name!, 'ui.load',
        bindToScope: true, startTimestamp: startTimestamp);
  }

  /// The time it takes until a fake frame has been triggered
  final finishFrameDuration = Duration(milliseconds: 50);

  TimeToInitialDisplayTracker getSut(
      {bool triggerApproximationTimeout = false}) {
    return TimeToInitialDisplayTracker(
        frameCallbackHandler: triggerApproximationTimeout
            ? DefaultFrameCallbackHandler()
            : FakeFrameCallbackHandler(
                postFrameCallbackDelay: finishFrameDuration));
  }
}
