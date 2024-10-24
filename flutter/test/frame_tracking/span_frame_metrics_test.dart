import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/frame_tracking/sentry_delayed_frames_tracker.dart';
import '../mocks.mocks.dart';

void main() {
  late _Fixture fixture;
  late SpanFrameMetrics metrics;

  setUp(() {
    fixture = _Fixture();
    metrics = fixture.getSut();
  });

  test('applyTo method sets data on non-root span', () {
    final span = MockSentrySpan();
    when(span.isRootSpan).thenReturn(false);

    metrics.applyTo(span);

    verify(span.setData(SpanDataConvention.totalFrames, 10)).called(1);
    verify(span.setData(SpanDataConvention.slowFrames, 2)).called(1);
    verify(span.setData(SpanDataConvention.frozenFrames, 1)).called(1);
    verify(span.setData(SpanDataConvention.framesDelay, 30)).called(1);
  });

  test('applyTo sets data and measurements on root spans', () {
    final span = MockSentrySpan();
    when(span.isRootSpan).thenReturn(true);
    final tracer = MockSentryTracer();
    when(span.tracer).thenReturn(tracer);

    metrics.applyTo(span);

    verify(tracer.setData(SpanDataConvention.totalFrames, 10)).called(1);
    verify(tracer.setData(SpanDataConvention.slowFrames, 2)).called(1);
    verify(tracer.setData(SpanDataConvention.frozenFrames, 1)).called(1);
    verify(tracer.setData(SpanDataConvention.framesDelay, 30)).called(1);

    verify(span.setMeasurement(SentryMeasurement.totalFramesName, 10))
        .called(1);
    verify(span.setMeasurement(SentryMeasurement.slowFramesName, 2)).called(1);
    verify(span.setMeasurement(SentryMeasurement.frozenFramesName, 1))
        .called(1);
    verify(span.setMeasurement(SentryMeasurement.framesDelayName, 30))
        .called(1);
  });
}

class _Fixture {
  SpanFrameMetrics getSut() {
    return SpanFrameMetrics(
      totalFrameCount: 10,
      slowFrameCount: 2,
      frozenFrameCount: 1,
      framesDelay: 30,
    );
  }
}
