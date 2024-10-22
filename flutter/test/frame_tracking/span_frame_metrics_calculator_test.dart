import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/src/frame_tracking/sentry_frame_tracker.dart';
import 'package:sentry_flutter/src/frame_tracking/span_frame_metrics_calculator.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  group('$SpanFrameMetricsCalculator', () {
    late _Fixture fixture;
    late SpanFrameMetricsCalculator calculator;

    setUp(() {
      fixture = _Fixture();
      calculator = fixture.getSut();
    });

    test('returns null when no frame timings are provided', () {
      final span = MockSentrySpan();
      when(span.startTimestamp).thenReturn(DateTime.now());
      when(span.endTimestamp)
          .thenReturn(DateTime.now().add(const Duration(seconds: 1)));

      final metrics = calculator.calculateFrameMetrics(
        span,
        exceededFrameTimings: [],
        expectedFrameDuration: const Duration(milliseconds: 16),
      );

      expect(metrics, isNull);
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

      final span = MockSentrySpan();
      when(span.startTimestamp).thenReturn(spanStart);
      when(span.endTimestamp).thenReturn(spanEnd);

      final metrics = calculator.calculateFrameMetrics(
        span,
        exceededFrameTimings: frameTimings,
        expectedFrameDuration: const Duration(milliseconds: 16),
      );

      expect(metrics, isNotNull);
      expect(metrics!.totalFrameCount, 63);
      expect(metrics.slowFrameCount, 1);
      expect(metrics.frozenFrameCount, 0);
      expect(metrics.framesDelay, 4);
    });

    test('calculates metrics for frames partially contained within the span',
        () {
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

      final span = MockSentrySpan();
      when(span.startTimestamp).thenReturn(spanStart);
      when(span.endTimestamp).thenReturn(spanEnd);

      final metrics = calculator.calculateFrameMetrics(
        span,
        exceededFrameTimings: frameTimings,
        expectedFrameDuration: const Duration(milliseconds: 16),
      );

      expect(metrics, isNotNull);
      expect(metrics!.totalFrameCount, 24);
      expect(metrics.slowFrameCount, 2);
      expect(metrics.frozenFrameCount, 0);
      expect(metrics.framesDelay, 134);
    });

    test('returns null when span has no end timestamp', () {
      final span = MockSentrySpan();
      when(span.startTimestamp).thenReturn(DateTime.now());
      when(span.endTimestamp).thenReturn(null);

      final metrics = calculator.calculateFrameMetrics(
        span,
        exceededFrameTimings: [],
        expectedFrameDuration: const Duration(milliseconds: 16),
      );

      expect(metrics, isNull);
    });
  });
}

class _Fixture {
  SpanFrameMetricsCalculator getSut() {
    final options = defaultTestOptions();
    return SpanFrameMetricsCalculator(options.logger);
  }
}
