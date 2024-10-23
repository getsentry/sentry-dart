import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/src/frame_tracking/span_frame_metrics.dart';
import '../mocks.mocks.dart';

/// Tests the [SpanFrameMetrics] data structure
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

    verify(span.setData(SpanFrameMetricKey.totalFrames.data, 10)).called(1);
    verify(span.setData(SpanFrameMetricKey.slowFrames.data, 2)).called(1);
    verify(span.setData(SpanFrameMetricKey.frozenFrames.data, 1)).called(1);
    verify(span.setData(SpanFrameMetricKey.framesDelay.data, 30)).called(1);
  });

  test('applyTo sets data and measurements on root spans', () {
    final span = MockSentrySpan();
    when(span.isRootSpan).thenReturn(true);
    final tracer = MockSentryTracer();
    when(span.tracer).thenReturn(tracer);

    metrics.applyTo(span);

    verify(span.setData(SpanFrameMetricKey.totalFrames.data, 10)).called(1);
    verify(span.setData(SpanFrameMetricKey.slowFrames.data, 2)).called(1);
    verify(span.setData(SpanFrameMetricKey.frozenFrames.data, 1)).called(1);
    verify(span.setData(SpanFrameMetricKey.framesDelay.data, 30)).called(1);

    verify(tracer.setData(SpanFrameMetricKey.totalFrames.data, 10)).called(1);
    verify(tracer.setData(SpanFrameMetricKey.slowFrames.data, 2)).called(1);
    verify(tracer.setData(SpanFrameMetricKey.frozenFrames.data, 1)).called(1);
    verify(tracer.setData(SpanFrameMetricKey.framesDelay.data, 30)).called(1);

    verify(span.setMeasurement(SpanFrameMetricKey.totalFrames.measurement, 10))
        .called(1);
    verify(span.setMeasurement(SpanFrameMetricKey.slowFrames.measurement, 2))
        .called(1);
    verify(span.setMeasurement(SpanFrameMetricKey.frozenFrames.measurement, 1))
        .called(1);
    verify(span.setMeasurement(SpanFrameMetricKey.framesDelay.measurement, 30))
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
