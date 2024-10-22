import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/frame_tracking/sentry_frame_tracker.dart';
import 'package:sentry_flutter/src/sentry_flutter_options.dart';

import '../mocks.dart';

void main() {
  late Fixture fixture;
  late SentryFrameTracker sut;

  setUp(() {
    fixture = Fixture();
  });

  tearDown(() {
    SentryFrameTracker.resetInstance();
  });

  // Simulate the clock time used within frame tracker so we don't rely on
  // actually measuring the time between frames
  void _setClockToEpochMillis(int millisSinceEpoch) {
    // ignore: invalid_use_of_internal_member
    fixture.options.clock =
        () => DateTime.fromMillisecondsSinceEpoch(millisSinceEpoch);
  }

  group('when enableFramesTracking is true', () {
    final expectedFrameDuration = Duration(milliseconds: 16);

    setUp(() {
      sut = fixture.getSut();
      sut.setExpectedFrameDuration(expectedFrameDuration);
      sut.resume();
    });

    test('does not capture frame if tracking is inactive', () {
      sut.pause();

      _setClockToEpochMillis(0);
      sut.startFrame();

      _setClockToEpochMillis(50);
      sut.endFrame();

      expect(sut.exceededFrames, isEmpty);
    });

    test('captures slow frames', () {
      _setClockToEpochMillis(0);
      sut.startFrame();

      _setClockToEpochMillis(50);
      sut.endFrame();

      expect(sut.exceededFrames, hasLength(1));
      expect(sut.exceededFrames.first.duration, Duration(milliseconds: 50));
    });

    test('captures frozen frames', () {
      _setClockToEpochMillis(0);
      sut.startFrame();

      _setClockToEpochMillis(800);
      sut.endFrame();

      expect(sut.exceededFrames, hasLength(1));
      expect(sut.exceededFrames.first.duration, Duration(milliseconds: 800));
    });

    test('does not capture frames within expected duration', () {
      _setClockToEpochMillis(0);
      sut.startFrame();

      _setClockToEpochMillis(15);
      sut.endFrame();

      expect(sut.exceededFrames, isEmpty);
    });

    test('getFramesIntersectingrange returns correct frames', () {
      // Frame entirely before range (should be excluded)
      _setClockToEpochMillis(0);
      sut.startFrame();
      _setClockToEpochMillis(10);
      sut.endFrame();

      // Frame starting before range and ending within (should be included)
      _setClockToEpochMillis(40);
      sut.startFrame();
      _setClockToEpochMillis(60);
      sut.endFrame();

      // Frame fully contained within range (should be included)
      _setClockToEpochMillis(80);
      sut.startFrame();
      _setClockToEpochMillis(120);
      sut.endFrame();

      // Frame starting within range and ending after (should be included)
      _setClockToEpochMillis(140);
      sut.startFrame();
      _setClockToEpochMillis(180);
      sut.endFrame();

      // Frame entirely after range (should be excluded)
      _setClockToEpochMillis(200);
      sut.startFrame();
      _setClockToEpochMillis(220);
      sut.endFrame();

      // Frame exactly matching range (edge case, should be included)
      _setClockToEpochMillis(50);
      sut.startFrame();
      _setClockToEpochMillis(150);
      sut.endFrame();

      final frames = sut.getFramesIntersecting(
        startTimestamp: DateTime.fromMillisecondsSinceEpoch(50),
        endTimestamp: DateTime.fromMillisecondsSinceEpoch(150),
      );

      expect(frames.length, 4);
      // frames are ordered by endTimestamp
      expect(frames[0].startTimestamp, DateTime.fromMillisecondsSinceEpoch(40));
      expect(frames[0].endTimestamp, DateTime.fromMillisecondsSinceEpoch(60));
      expect(frames[1].startTimestamp, DateTime.fromMillisecondsSinceEpoch(80));
      expect(frames[1].endTimestamp, DateTime.fromMillisecondsSinceEpoch(120));
      expect(frames[2].startTimestamp, DateTime.fromMillisecondsSinceEpoch(50));
      expect(frames[2].endTimestamp, DateTime.fromMillisecondsSinceEpoch(150));
      expect(
          frames[3].startTimestamp, DateTime.fromMillisecondsSinceEpoch(140));
      expect(frames[3].endTimestamp, DateTime.fromMillisecondsSinceEpoch(180));
    });

    test('removeFramesBefore removes correct frames', () {
      _setClockToEpochMillis(0);
      sut.startFrame();
      _setClockToEpochMillis(50);
      sut.endFrame();

      _setClockToEpochMillis(100);
      sut.startFrame();
      _setClockToEpochMillis(200);
      sut.endFrame();

      sut.removeFramesBefore(DateTime.fromMillisecondsSinceEpoch(75));

      expect(sut.exceededFrames, hasLength(1));
      expect(sut.exceededFrames.first.startTimestamp,
          DateTime.fromMillisecondsSinceEpoch(100));
    });

    test('pause stops frame tracking', () {
      expect(sut.isTrackingActive, isTrue);

      sut.pause();
      expect(sut.isTrackingActive, isFalse);

      _setClockToEpochMillis(0);
      sut.startFrame();
      _setClockToEpochMillis(50);
      sut.endFrame();

      expect(sut.exceededFrames, isEmpty);
    });

    test('resumeIfNeeded resumes frame tracking', () {
      sut.pause();
      expect(sut.isTrackingActive, isFalse);

      sut.resume();
      expect(sut.isTrackingActive, isTrue);

      _setClockToEpochMillis(0);
      sut.startFrame();
      _setClockToEpochMillis(50);
      sut.endFrame();

      expect(sut.exceededFrames, hasLength(1));
    });

    test('clear removes all tracked frames and pauses tracking', () {
      sut.resume();

      _setClockToEpochMillis(0);
      sut.startFrame();
      _setClockToEpochMillis(50);
      sut.endFrame();

      expect(sut.exceededFrames, isNotEmpty);
      expect(sut.isTrackingActive, isTrue);

      sut.clear();

      expect(sut.exceededFrames, isEmpty);
      expect(sut.isTrackingActive, isFalse);
    });
  });

  group('when enableFramesTracking is false', () {
    setUp(() {
      sut = fixture.getSut(enableFramesTracking: false);
    });

    test('does not capture frames', () {
      sut.resume();

      _setClockToEpochMillis(0);
      sut.startFrame();
      _setClockToEpochMillis(50);
      sut.endFrame();

      expect(sut.exceededFrames, isEmpty);
    });
  });

  test('updateExpectedFrameDuration only sets duration once', () {
    sut = fixture.getSut();

    sut.setExpectedFrameDuration(Duration(milliseconds: 16));
    sut.setExpectedFrameDuration(Duration(milliseconds: 33));

    expect(sut.expectedFrameDuration, Duration(milliseconds: 16));
  });

  test('SentryFrameTracker is a singleton', () {
    final tracker1 = fixture.getSut();
    final tracker2 = fixture.getSut();

    expect(identical(tracker1, tracker2), isTrue);
  });
}

class Fixture {
  late SentryFlutterOptions options = defaultTestOptions();

  SentryFrameTracker getSut({bool enableFramesTracking = true}) {
    options.enableFramesTracking = enableFramesTracking;
    return SentryFrameTracker(options);
  }
}
