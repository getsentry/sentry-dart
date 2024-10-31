import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/frames_tracking/sentry_delayed_frames_tracker.dart';
import 'package:sentry_flutter/src/sentry_flutter_options.dart';

import '../mocks.dart';

void main() {
  late Fixture fixture;
  late SentryDelayedFramesTracker sut;

  setUp(() {
    fixture = Fixture();
  });

  group('when enableFramesTracking is true', () {
    setUp(() {
      sut = fixture.getSut();
      sut.resume();
    });

    test('does not capture frame if tracking is inactive', () {
      sut.pause();

      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(0),
          DateTime.fromMillisecondsSinceEpoch(50));

      expect(sut.delayedFrames, isEmpty);
    });

    test('stop collecting frames when maxFramesCount is reached', () {
      for (int i = 0; i < maxDelayedFramesCount + 100; i++) {
        sut.addFrame(DateTime.fromMillisecondsSinceEpoch(0 + i),
            DateTime.fromMillisecondsSinceEpoch(50 + i));
      }

      expect(sut.delayedFrames.length, maxDelayedFramesCount);
    });

    test('captures slow frames', () {
      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(0),
          DateTime.fromMillisecondsSinceEpoch(50));

      expect(sut.delayedFrames, hasLength(1));
      expect(sut.delayedFrames.first.duration, Duration(milliseconds: 50));
    });

    test('captures frozen frames', () {
      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(0),
          DateTime.fromMillisecondsSinceEpoch(800));

      expect(sut.delayedFrames, hasLength(1));
      expect(sut.delayedFrames.first.duration, Duration(milliseconds: 800));
    });

    test('does not capture frames within expected duration', () {
      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(0),
          DateTime.fromMillisecondsSinceEpoch(10));

      expect(sut.delayedFrames, isEmpty);
    });

    test('getFramesIntersectingRange returns correct frames', () {
      // Frame entirely before range (should be excluded)
      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(0),
          DateTime.fromMillisecondsSinceEpoch(10));

      // Frame starting before range and ending within (should be included)
      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(40),
          DateTime.fromMillisecondsSinceEpoch(60));

      // Frame fully contained within range (should be included)
      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(80),
          DateTime.fromMillisecondsSinceEpoch(120));

      // Frame starting within range and ending after (should be included)
      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(140),
          DateTime.fromMillisecondsSinceEpoch(180));

      // Frame entirely after range (should be excluded)
      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(200),
          DateTime.fromMillisecondsSinceEpoch(220));

      final frames = sut.getFramesIntersecting(
        startTimestamp: DateTime.fromMillisecondsSinceEpoch(50),
        endTimestamp: DateTime.fromMillisecondsSinceEpoch(150),
      );

      expect(frames.length, 3);
      expect(frames[0].startTimestamp, DateTime.fromMillisecondsSinceEpoch(40));
      expect(frames[0].endTimestamp, DateTime.fromMillisecondsSinceEpoch(60));
      expect(frames[1].startTimestamp, DateTime.fromMillisecondsSinceEpoch(80));
      expect(frames[1].endTimestamp, DateTime.fromMillisecondsSinceEpoch(120));
      expect(
          frames[2].startTimestamp, DateTime.fromMillisecondsSinceEpoch(140));
      expect(frames[2].endTimestamp, DateTime.fromMillisecondsSinceEpoch(180));
    });

    test('pause stops frame tracking', () {
      expect(sut.isTrackingActive, isTrue);

      sut.pause();
      expect(sut.isTrackingActive, isFalse);

      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(0),
          DateTime.fromMillisecondsSinceEpoch(50));

      expect(sut.delayedFrames, isEmpty);
    });

    test('resumeIfNeeded resumes frame tracking', () {
      sut.pause();
      expect(sut.isTrackingActive, isFalse);

      sut.resume();
      expect(sut.isTrackingActive, isTrue);

      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(0),
          DateTime.fromMillisecondsSinceEpoch(50));

      expect(sut.delayedFrames, hasLength(1));
    });

    test('clear removes all tracked frames and pauses tracking', () {
      sut.resume();

      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(0),
          DateTime.fromMillisecondsSinceEpoch(50));

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
      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(100),
          DateTime.fromMillisecondsSinceEpoch(120));

      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(200),
          DateTime.fromMillisecondsSinceEpoch(216));

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
      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(-50),
          DateTime.fromMillisecondsSinceEpoch(50));

      // Frame starts within span and ends after span
      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(400),
          DateTime.fromMillisecondsSinceEpoch(600));

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
      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(100),
          DateTime.fromMillisecondsSinceEpoch(900));

      final metrics = sut.getFrameMetrics(
        spanStartTimestamp: spanStart,
        spanEndTimestamp: spanEnd,
      );

      expect(metrics, isNotNull);
      expect(metrics!.frozenFrameCount, 1);
      expect(metrics.slowFrameCount, 0);
      expect(metrics.framesDelay, 784); // 800ms - 16ms = 784ms delay
    });

    test('removeIrrelevantFrames removes the correct frames', () {
      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(20),
          DateTime.fromMillisecondsSinceEpoch(50));

      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(60),
          DateTime.fromMillisecondsSinceEpoch(80));

      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(90),
          DateTime.fromMillisecondsSinceEpoch(110));

      expect(sut.delayedFrames.length, 3);

      sut.removeIrrelevantFrames(DateTime.fromMillisecondsSinceEpoch(89));

      expect(sut.delayedFrames.length, 1);
    });
  });

  // todo: test removeIrrelevantFrames

  group('when enableFramesTracking is false', () {
    setUp(() {
      sut = fixture.getSut(enableFramesTracking: false);
    });

    test('does not capture frames', () {
      sut.resume();

      sut.addFrame(DateTime.fromMillisecondsSinceEpoch(0),
          DateTime.fromMillisecondsSinceEpoch(50));

      expect(sut.delayedFrames, isEmpty);
    });
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
