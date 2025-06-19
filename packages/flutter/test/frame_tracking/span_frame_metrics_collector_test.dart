import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_flutter/src/frames_tracking/sentry_delayed_frames_tracker.dart';
import 'package:sentry_flutter/src/frames_tracking/span_frame_metrics_collector.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('clear() clears activeSpans and frame tracker', () async {
    final sut = fixture.getSut();
    final span = MockSentrySpan();
    await sut.onSpanStarted(span);

    sut.clear();

    expect(sut.activeSpans, isEmpty);
    verify(fixture.mockFrameTracker.clear()).called(1);
  });

  group('onSpanStarted', () {
    test('adds span to activeSpans and resumes tracker', () async {
      final sut = fixture.getSut();
      final span = MockSentrySpan();
      await sut.onSpanStarted(span);

      expect(sut.activeSpans, contains(span));
      expect(fixture.resumeFrameTrackingCalledCount, 1);
    });

    test('ignores NoOpSentrySpan', () async {
      final sut = fixture.getSut();
      final span = NoOpSentrySpan();

      await sut.onSpanStarted(span);

      expect(sut.activeSpans, isEmpty);
      expect(fixture.resumeFrameTrackingCalledCount, 0);
    });
  });

  group('onSpanFinished', () {
    test('applies metrics and removes span from activeSpans', () async {
      final sut = fixture.getSut();
      // ignore: invalid_use_of_internal_member
      final startTime = fixture.options.clock();
      final endTime = startTime.add(Duration(seconds: 1));
      fixture.options.tracesSampleRate = 1.0;
      final hub = Hub(fixture.options);
      final tracer = SentryTracer(SentryTransactionContext('name', 'op'), hub,
          startTimestamp: startTime);
      final span = SentrySpan(tracer, SentrySpanContext(operation: 'op'), hub,
          startTimestamp: startTime, isRootSpan: true);

      final metrics = SpanFrameMetrics(
        totalFrameCount: 10,
        slowFrameCount: 2,
        frozenFrameCount: 1,
        framesDelay: 500,
      );
      when(fixture.mockFrameTracker.getFrameMetrics(
        spanStartTimestamp: startTime,
        spanEndTimestamp: endTime,
      )).thenReturn(metrics);

      // First add the span
      await sut.onSpanStarted(span);
      expect(sut.activeSpans, contains(span));

      // Then finish it
      await sut.onSpanFinished(span, endTime);

      // Verify actual data on the span
      expect(tracer.data[SpanDataConvention.totalFrames], 10);
      expect(tracer.data[SpanDataConvention.slowFrames], 2);
      expect(tracer.data[SpanDataConvention.frozenFrames], 1);
      expect(tracer.data[SpanDataConvention.framesDelay], 500);
      expect(tracer.measurements[SentryMeasurement.totalFramesName]?.value, 10);
      expect(tracer.measurements[SentryMeasurement.slowFramesName]?.value, 2);
      expect(tracer.measurements[SentryMeasurement.frozenFramesName]?.value, 1);
      expect(
          // This code verifies that the delay measurements added to the SentryTracer
          // are correctly capturing the framesDelay value. The test checks if the
          // framesDelayName measurement in the tracer accurately reflects the expected
          tracer.measurements[SentryMeasurement.framesDelayName]?.value,
          500);
      expect(sut.activeSpans, isEmpty);
    });

    test('applies metrics to multiple spans and removes spans from activeSpans',
        () async {
      final sut = fixture.getSut();
      fixture.options.tracesSampleRate = 1.0;
      final hub = Hub(fixture.options);

      // ignore: invalid_use_of_internal_member
      final startTimeForSpan1 = fixture.options.clock();
      final endTimeForSpan1 = startTimeForSpan1.add(Duration(seconds: 1));
      final tracer = SentryTracer(SentryTransactionContext('name', 'op'), hub,
          startTimestamp: startTimeForSpan1);
      final span1 = SentrySpan(tracer, SentrySpanContext(operation: 'op'), hub,
          startTimestamp: startTimeForSpan1, isRootSpan: true);

      final startTimeForSpan2 =
          startTimeForSpan1.add(Duration(milliseconds: 100));
      final endTimeForSpan2 = startTimeForSpan2.add(Duration(seconds: 100));
      final span2 = span1.startChild('child op',
          startTimestamp: startTimeForSpan2) as SentrySpan;

      final metricsForSpan1 = SpanFrameMetrics(
        totalFrameCount: 10,
        slowFrameCount: 2,
        frozenFrameCount: 1,
        framesDelay: 500,
      );
      when(fixture.mockFrameTracker.getFrameMetrics(
        spanStartTimestamp: startTimeForSpan1,
        spanEndTimestamp: endTimeForSpan1,
      )).thenReturn(metricsForSpan1);

      final metricsForSpan2 = SpanFrameMetrics(
        totalFrameCount: 5,
        slowFrameCount: 1,
        frozenFrameCount: 3,
        framesDelay: 400,
      );
      when(fixture.mockFrameTracker.getFrameMetrics(
        spanStartTimestamp: startTimeForSpan2,
        spanEndTimestamp: endTimeForSpan2,
      )).thenReturn(metricsForSpan2);

      // First add the spans
      await sut.onSpanStarted(span1);
      await sut.onSpanStarted(span2);
      expect(sut.activeSpans, containsAll([span1, span2]));

      // Then finish them
      await sut.onSpanFinished(span2, endTimeForSpan2);
      await sut.onSpanFinished(span1, endTimeForSpan1);

      // Verify root data
      expect(tracer.data[SpanDataConvention.totalFrames], 10);
      expect(tracer.data[SpanDataConvention.slowFrames], 2);
      expect(tracer.data[SpanDataConvention.frozenFrames], 1);
      expect(tracer.data[SpanDataConvention.framesDelay], 500);
      expect(tracer.measurements[SentryMeasurement.totalFramesName]?.value, 10);
      expect(tracer.measurements[SentryMeasurement.slowFramesName]?.value, 2);
      expect(tracer.measurements[SentryMeasurement.frozenFramesName]?.value, 1);
      expect(
          tracer.measurements[SentryMeasurement.framesDelayName]?.value, 500);

      // Verify child span data
      expect(span2.data[SpanDataConvention.totalFrames], 5);
      expect(span2.data[SpanDataConvention.slowFrames], 1);
      expect(span2.data[SpanDataConvention.frozenFrames], 3);
      expect(span2.data[SpanDataConvention.framesDelay], 400);

      expect(sut.activeSpans, isEmpty);
    });

    test('clears tracker when no active span', () async {
      final sut = fixture.getSut();
      final span = MockSentrySpan();
      // ignore: invalid_use_of_internal_member
      final startTime = fixture.options.clock();
      final endTime = startTime.add(Duration(seconds: 1));
      when(span.startTimestamp).thenReturn(startTime);
      when(fixture.mockFrameTracker.getFrameMetrics(
              spanStartTimestamp: startTime, spanEndTimestamp: endTime))
          .thenReturn(null);

      await sut.onSpanFinished(span, endTime);

      verify(fixture.mockFrameTracker.clear()).called(1);
      expect(fixture.pauseFrameTrackingCalledCount, 1);
    });

    test('does not clear tracker when active spans exist', () async {
      final sut = fixture.getSut();
      final span = MockSentrySpan();
      final span2 = MockSentrySpan();

      // ignore: invalid_use_of_internal_member
      final startTime = fixture.options.clock();
      final endTime = startTime.add(Duration(seconds: 1));
      final startTime2 = startTime.add(Duration(seconds: 2));
      when(span.startTimestamp).thenReturn(startTime);
      when(span2.startTimestamp).thenReturn(startTime2);
      when(fixture.mockFrameTracker.getFrameMetrics(
              spanStartTimestamp: startTime, spanEndTimestamp: endTime))
          .thenReturn(null);
      when(fixture.mockFrameTracker.getFrameMetrics(
              spanStartTimestamp: startTime2,
              spanEndTimestamp: anyNamed('spanEndTimestamp')))
          .thenReturn(null);

      await sut.onSpanStarted(span);
      await sut.onSpanStarted(span2);

      await sut.onSpanFinished(span, endTime);

      verifyNever(fixture.mockFrameTracker.clear());
      expect(fixture.pauseFrameTrackingCalledCount, 0);
      verify(fixture.mockFrameTracker.removeIrrelevantFrames(any)).called(1);
    });
  });
}

class Fixture {
  final options = defaultTestOptions();
  final mockFrameTracker = MockSentryDelayedFramesTracker();
  int resumeFrameTrackingCalledCount = 0;
  int pauseFrameTrackingCalledCount = 0;

  SpanFrameMetricsCollector getSut() {
    return SpanFrameMetricsCollector(
      options,
      mockFrameTracker,
      resumeFrameTracking: () => resumeFrameTrackingCalledCount += 1,
      pauseFrameTracking: () => pauseFrameTrackingCalledCount += 1,
    );
  }
}
