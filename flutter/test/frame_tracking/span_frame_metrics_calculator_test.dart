import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/frame_tracking/sentry_delayed_frames_tracker.dart';
import 'package:sentry_flutter/src/frame_tracking/span_frame_metrics_calculator.dart';

void main() {
  late _Fixture fixture;
  late SpanFrameMetricsCalculator calculator;

  setUp(() {
    fixture = _Fixture();
    calculator = fixture.getSut();
  });

  test(
      'returns metrics with only total frames when no exceeded frame timings are provided',
      () {
    final spanStart = DateTime.now();
    final spanEnd = spanStart.add(const Duration(seconds: 1));

    final metrics = calculator.calculateFrameMetrics(
      spanStartTimestamp: spanStart,
      spanEndTimestamp: spanEnd,
      delayedFrames: [],
      expectedFrameDuration: const Duration(milliseconds: 16),
    );

    expect(metrics, isNotNull);
    expect(metrics!.totalFrameCount, 63);
    expect(metrics.slowFrameCount, 0);
    expect(metrics.frozenFrameCount, 0);
    expect(metrics.framesDelay, 0);
  });

  test('calculates metrics for frames fully contained within the span', () {
    final spanStart = DateTime.now();
    final spanEnd = spanStart.add(const Duration(seconds: 1));

    final frameTimings = [
      SentryFrameTiming(
        startTimestamp: spanStart.add(const Duration(milliseconds: 100)),
        endTimestamp: spanStart.add(const Duration(milliseconds: 120)),
      ),
      SentryFrameTiming(
        startTimestamp: spanStart.add(const Duration(milliseconds: 200)),
        endTimestamp: spanStart.add(const Duration(milliseconds: 216)),
      ),
    ];

    final metrics = calculator.calculateFrameMetrics(
      spanStartTimestamp: spanStart,
      spanEndTimestamp: spanEnd,
      delayedFrames: frameTimings,
      expectedFrameDuration: const Duration(milliseconds: 16),
    );

    expect(metrics, isNotNull);
    expect(metrics!.totalFrameCount, 63);
    expect(metrics.slowFrameCount, 1);
    expect(metrics.frozenFrameCount, 0);
    expect(metrics.framesDelay, 4);
  });

  test('calculates metrics for frames partially contained within the span', () {
    final spanStart = DateTime.now();
    final spanEnd = spanStart.add(const Duration(milliseconds: 500));

    final frameTimings = [
      // Frame starts before span and ends within span
      SentryFrameTiming(
        startTimestamp: spanStart.subtract(const Duration(milliseconds: 50)),
        endTimestamp: spanStart.add(const Duration(milliseconds: 50)),
      ),
      // Frame starts within span and ends after span
      SentryFrameTiming(
        startTimestamp: spanStart.add(const Duration(milliseconds: 400)),
        endTimestamp: spanStart.add(const Duration(milliseconds: 600)),
      ),
    ];

    final metrics = calculator.calculateFrameMetrics(
      spanStartTimestamp: spanStart,
      spanEndTimestamp: spanEnd,
      delayedFrames: frameTimings,
      expectedFrameDuration: const Duration(milliseconds: 16),
    );

    expect(metrics, isNotNull);
    expect(metrics!.totalFrameCount, 24);
    expect(metrics.slowFrameCount, 2);
    expect(metrics.frozenFrameCount, 0);
    expect(metrics.framesDelay, 134);
  });
}

class _Fixture {
  SpanFrameMetricsCalculator getSut() {
    return SpanFrameMetricsCalculator();
  }
}
