import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/app_start/app_start_tracker.dart';
import 'package:sentry_flutter/src/navigation/time_to_initial_display_tracker.dart';

import '../fake_frame_callback_handler.dart';
import '../mocks.dart';
import 'package:sentry/src/sentry_tracer.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('app start', () {
    test('tracking creates and finishes ttid span with correct measurements', () async {
      final sut = fixture.getSut();
      final transaction = fixture.hub.startTransaction('fake', 'fake')
          as SentryTracer;
      final startTimestamp = DateTime.now();
      final appStartInfo = AppStartInfo(
          startTimestamp,
          startTimestamp.add(Duration(milliseconds: 10)),
          SentryMeasurement.coldAppStart(Duration(milliseconds: 10)));

      await sut.trackAppStart(transaction, appStartInfo, 'route ("/")');

      final children = transaction.children;
      expect(children, hasLength(1));

      final ttidSpan = children.first;
      expect(ttidSpan.context.operation, SentrySpanOperations.uiTimeToInitialDisplay);
      expect(ttidSpan.finished, isTrue);
      expect(ttidSpan.context.description, 'route ("/") initial display');
      expect(ttidSpan.origin, SentryTraceOrigins.autoUiTimeToDisplay);

      final ttidMeasurement = transaction.measurements['time_to_initial_display'];
      expect(ttidMeasurement, isNotNull);
      expect(ttidMeasurement?.unit, DurationSentryMeasurementUnit.milliSecond);
      expect(ttidMeasurement?.value, 10);

      final appStartMeasurement = transaction.measurements['app_start_cold'];
      expect(appStartMeasurement, isNotNull);
      expect(appStartMeasurement?.unit, DurationSentryMeasurementUnit.milliSecond);
      expect(appStartMeasurement?.value, 10);
    });
  });

  group('regular route', () {
    test('approximation tracking creates and finishes ttid span with correct measurements', () async {
      final sut = fixture.getSut();
      final transaction = fixture.hub.startTransaction('fake', 'fake')
          as SentryTracer;
      final startTimestamp = DateTime.now();

      await sut.trackRegularRoute(transaction, startTimestamp, 'regular route');

      final children = transaction.children;
      expect(children, hasLength(1));

      final ttidSpan = children.first;
      expect(ttidSpan.context.operation, SentrySpanOperations.uiTimeToInitialDisplay);
      expect(ttidSpan.finished, isTrue);
      expect(ttidSpan.context.description, 'regular route initial display');
      expect(ttidSpan.origin, SentryTraceOrigins.autoUiTimeToDisplay);

      final ttidMeasurement = transaction.measurements['time_to_initial_display'];
      expect(ttidMeasurement, isNotNull);
      expect(ttidMeasurement?.unit, DurationSentryMeasurementUnit.milliSecond);
      expect(ttidMeasurement?.value, greaterThan(fixture.finishAfterDuration.inMilliseconds));
      expect(ttidMeasurement?.value, lessThan(fixture.finishAfterDuration.inMilliseconds + 10));
    });

    test('manual tracking creates and finishes ttid span with correct measurements', () async {
      final sut = fixture.getSut();
      final transaction = fixture.hub.startTransaction('fake', 'fake')
          as SentryTracer;
      final startTimestamp = DateTime.now();

      sut.markAsManual();
      Future.delayed(fixture.finishAfterDuration, () {
        sut.completeTracking();
      });
      await sut.trackRegularRoute(transaction, startTimestamp, 'regular route');

      final children = transaction.children;
      expect(children, hasLength(1));

      final ttidSpan = children.first;
      expect(ttidSpan.context.operation, SentrySpanOperations.uiTimeToInitialDisplay);
      expect(ttidSpan.finished, isTrue);
      expect(ttidSpan.context.description, 'regular route initial display');
      expect(ttidSpan.origin, SentryTraceOrigins.manualUiTimeToDisplay);

      final ttidMeasurement = transaction.measurements['time_to_initial_display'];
      expect(ttidMeasurement, isNotNull);
      expect(ttidMeasurement?.unit, DurationSentryMeasurementUnit.milliSecond);
      expect(ttidMeasurement?.value, greaterThan(fixture.finishAfterDuration.inMilliseconds));
      expect(ttidMeasurement?.value, lessThan(fixture.finishAfterDuration.inMilliseconds + 10));
    });
  });

  group('determineEndtime', () {
    test('can complete automatically in approximation mode', () async {
      final sut = fixture.getSut();

      final futureEndTime = sut.determineEndTime();

      expect(futureEndTime, completes);
    });

    test('prevents automatic completion in manual mode', () async {
      final sut = fixture.getSut();

      sut.markAsManual();
      final futureEndTime = sut.determineEndTime();

      expect(futureEndTime, doesNotComplete);
    });

    test('can complete manually in manual mode', () async {
      final sut = fixture.getSut();

      sut.markAsManual();
      final futureEndTime = sut.determineEndTime();

      sut.completeTracking();
      expect(futureEndTime, completes);
    });

    test('returns the correct approximation end time', () async {
      final startTime = DateTime.now();
      final sut = fixture.getSut();

      final futureEndTime = sut.determineEndTime();

      final endTime = await futureEndTime;
      expect(endTime?.difference(startTime).inSeconds,
          fixture.finishAfterDuration.inSeconds);
    });

    test('returns the correct manual end time', () async {
      final startTime = DateTime.now();
      final sut = fixture.getSut();

      sut.markAsManual();
      final futureEndTime = sut.determineEndTime();

      Future.delayed(fixture.finishAfterDuration, () {
        sut.completeTracking();
      });

      final endTime = await futureEndTime;
      expect(endTime?.difference(startTime).inSeconds,
          fixture.finishAfterDuration.inSeconds);
    });
  });
}

class Fixture {
  final hub = Hub(SentryFlutterOptions(dsn: fakeDsn)..tracesSampleRate = 1.0);
  final finishAfterDuration = Duration(milliseconds: 100);
  late final fakeFrameCallbackHandler =
      FakeFrameCallbackHandler(finishAfterDuration: finishAfterDuration);

  TimeToInitialDisplayTracker getSut() {
    final sut = TimeToInitialDisplayTracker();
    sut.frameCallbackHandler = fakeFrameCallbackHandler;
    return sut;
  }
}
