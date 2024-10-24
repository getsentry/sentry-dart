import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/frame_tracking/sentry_delayed_frames_tracker.dart';
import 'package:sentry_flutter/src/sentry_flutter_options.dart';

import '../mocks.dart';

void main() {
  late Fixture fixture;
  late SentryDelayedFramesTracker sut;

  setUp(() {
    fixture = Fixture();
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
      sut.resume();
    });

    test('does not capture frame if tracking is inactive', () {
      sut.pause();

      _setClockToEpochMillis(0);
      sut.startFrame();

      _setClockToEpochMillis(50);
      sut.endFrame();

      expect(sut.delayedFrames, isEmpty);
    });

    test('clears tracker when frame in memory limit reached', () {
      for (int i = 0; i <= maxFramesCount; i++) {
        _setClockToEpochMillis(i);
        sut.startFrame();

        _setClockToEpochMillis(50 + i);
        sut.endFrame();
      }

      expect(sut.delayedFrames, isEmpty);
      expect(sut.isTrackingActive, isFalse);
    });

    test('captures slow frames', () {
      _setClockToEpochMillis(0);
      sut.startFrame();

      _setClockToEpochMillis(50);
      sut.endFrame();

      expect(sut.delayedFrames, hasLength(1));
      expect(sut.delayedFrames.first.duration, Duration(milliseconds: 50));
    });

    test('captures frozen frames', () {
      _setClockToEpochMillis(0);
      sut.startFrame();

      _setClockToEpochMillis(800);
      sut.endFrame();

      expect(sut.delayedFrames, hasLength(1));
      expect(sut.delayedFrames.first.duration, Duration(milliseconds: 800));
    });

    test('does not capture frames within expected duration', () {
      _setClockToEpochMillis(0);
      sut.startFrame();

      _setClockToEpochMillis(15);
      sut.endFrame();

      expect(sut.delayedFrames, isEmpty);
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

    test('pause stops frame tracking', () {
      expect(sut.isTrackingActive, isTrue);

      sut.pause();
      expect(sut.isTrackingActive, isFalse);

      _setClockToEpochMillis(0);
      sut.startFrame();
      _setClockToEpochMillis(50);
      sut.endFrame();

      expect(sut.delayedFrames, isEmpty);
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

      expect(sut.delayedFrames, hasLength(1));
    });

    test('clear removes all tracked frames and pauses tracking', () {
      sut.resume();

      _setClockToEpochMillis(0);
      sut.startFrame();
      _setClockToEpochMillis(50);
      sut.endFrame();

      expect(sut.delayedFrames, isNotEmpty);
      expect(sut.isTrackingActive, isTrue);

      sut.clear();

      expect(sut.delayedFrames, isEmpty);
      expect(sut.isTrackingActive, isFalse);
    });

    test('returns metrics with only total frames when no delayed frames exist',
        () {
      final spanStart = DateTime.fromMillisecondsSinceEpoch(0);
      final spanEnd = spanStart.add(const Duration(seconds: 1));

      final metrics = sut.getFrameMetrics(
        spanStartTimestamp: spanStart,
        spanEndTimestamp: spanEnd,
      );

      expect(metrics, isNotNull);
      expect(metrics!.totalFrameCount, 63); // 1000ms / 16ms ≈ 63 frames
      expect(metrics.slowFrameCount, 0);
      expect(metrics.frozenFrameCount, 0);
      expect(metrics.framesDelay, 0);
    });

    test('calculates metrics for frames fully contained within span', () {
      final spanStart = DateTime.fromMillisecondsSinceEpoch(0);
      final spanEnd = spanStart.add(const Duration(seconds: 1));

      // Add two frames: one slow (20ms over) and one normal-ish
      _setClockToEpochMillis(100);
      sut.startFrame();
      _setClockToEpochMillis(120); // 20ms duration
      sut.endFrame();

      _setClockToEpochMillis(200);
      sut.startFrame();
      _setClockToEpochMillis(216); // 16ms duration
      sut.endFrame();

      final metrics = sut.getFrameMetrics(
        spanStartTimestamp: spanStart,
        spanEndTimestamp: spanEnd,
      );

      expect(metrics, isNotNull);
      expect(metrics!.totalFrameCount, 63);
      expect(metrics.slowFrameCount, 1);
      expect(metrics.frozenFrameCount, 0);
      expect(metrics.framesDelay, 4); // 20ms - 16ms = 4ms delay
    });

    test('calculates metrics for frames partially contained within span', () {
      final spanStart = DateTime.fromMillisecondsSinceEpoch(0);
      final spanEnd = spanStart.add(const Duration(milliseconds: 500));

      // Frame starts before span and ends within span
      _setClockToEpochMillis(-50);
      sut.startFrame();
      _setClockToEpochMillis(50);
      sut.endFrame();

      // Frame starts within span and ends after span
      _setClockToEpochMillis(400);
      sut.startFrame();
      _setClockToEpochMillis(600);
      sut.endFrame();

      final metrics = sut.getFrameMetrics(
        spanStartTimestamp: spanStart,
        spanEndTimestamp: spanEnd,
      );

      expect(metrics, isNotNull);
      expect(metrics!.totalFrameCount, 24); // ~500ms / 16ms = 31 frames
      expect(metrics.slowFrameCount, 2);
      expect(metrics.frozenFrameCount, 0);
      expect(metrics.framesDelay, 134);
    });

    test('calculates metrics for frozen frames', () {
      final spanStart = DateTime.fromMillisecondsSinceEpoch(0);
      final spanEnd = spanStart.add(const Duration(seconds: 1));

      // Add a frozen frame (800ms)
      _setClockToEpochMillis(100);
      sut.startFrame();
      _setClockToEpochMillis(900);
      sut.endFrame();

      final metrics = sut.getFrameMetrics(
        spanStartTimestamp: spanStart,
        spanEndTimestamp: spanEnd,
      );

      expect(metrics, isNotNull);
      expect(metrics!.frozenFrameCount, 1);
      expect(metrics.slowFrameCount, 0);
      expect(metrics.framesDelay, 784); // 800ms - 16ms = 784ms delay
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

      expect(sut.delayedFrames, isEmpty);
    });
  });

  test('SentryFrameTracker is a singleton', () {
    final tracker1 = fixture.getSut();
    final tracker2 = fixture.getSut();

    expect(identical(tracker1, tracker2), isTrue);
  });
}

class Fixture {
  late SentryFlutterOptions options = defaultTestOptions();

  SentryDelayedFramesTracker getSut(
      {bool enableFramesTracking = true,
      Duration expectedFrameDuration = const Duration(milliseconds: 16)}) {
    options.enableFramesTracking = enableFramesTracking;
    return SentryDelayedFramesTracker(options, expectedFrameDuration);
  }
}
