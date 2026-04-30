// ignore_for_file: invalid_use_of_internal_member

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

  group('SpanFrameMetricsCollector with LegacyInstrumentationSpan', () {
    test('filters out NoOpSentrySpan', () async {
      final sut = fixture.getSut();
      final noopSpan = NoOpSentrySpan();
      final wrapper = LegacyInstrumentationSpan(noopSpan);

      await sut.startTracking(wrapper);

      expect(sut.activeSpans, isEmpty);
      expect(fixture.resumeFrameTrackingCalledCount, 0);
    });

    test('tracks legacy spans and applies metrics', () async {
      final sut = fixture.getSut();
      final startTime = fixture.options.clock();
      final endTime = startTime.add(Duration(seconds: 1));
      fixture.options.tracesSampleRate = 1.0;
      final hub = Hub(fixture.options);
      final tracer = SentryTracer(SentryTransactionContext('name', 'op'), hub,
          startTimestamp: startTime);
      final span = SentrySpan(tracer, SentrySpanContext(operation: 'op'), hub,
          startTimestamp: startTime, isRootSpan: true);
      final wrapper = LegacyInstrumentationSpan(span);

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

      await sut.startTracking(wrapper);
      expect(sut.activeSpans, contains(wrapper));
      expect(fixture.resumeFrameTrackingCalledCount, 1);

      await sut.finishTracking(wrapper, endTime);

      expect(tracer.data[SpanDataConvention.totalFrames], 10);
      expect(tracer.data[SpanDataConvention.slowFrames], 2);
      expect(tracer.data[SpanDataConvention.frozenFrames], 1);
      expect(tracer.data[SpanDataConvention.framesDelay], 500);
      expect(tracer.measurements[SentryMeasurement.totalFramesName]?.value, 10);
      expect(tracer.measurements[SentryMeasurement.slowFramesName]?.value, 2);
      expect(tracer.measurements[SentryMeasurement.frozenFramesName]?.value, 1);
      expect(
          tracer.measurements[SentryMeasurement.framesDelayName]?.value, 500);
      expect(sut.activeSpans, isEmpty);
    });

    test('handles multiple concurrent legacy spans', () async {
      final sut = fixture.getSut();
      fixture.options.tracesSampleRate = 1.0;
      final hub = Hub(fixture.options);

      final startTimeForSpan1 = fixture.options.clock();
      final endTimeForSpan1 = startTimeForSpan1.add(Duration(seconds: 1));
      final tracer = SentryTracer(SentryTransactionContext('name', 'op'), hub,
          startTimestamp: startTimeForSpan1);
      final span1 = SentrySpan(tracer, SentrySpanContext(operation: 'op'), hub,
          startTimestamp: startTimeForSpan1, isRootSpan: true);
      final wrapper1 = LegacyInstrumentationSpan(span1);

      final startTimeForSpan2 =
          startTimeForSpan1.add(Duration(milliseconds: 100));
      final endTimeForSpan2 = startTimeForSpan2.add(Duration(seconds: 100));
      final span2 = span1.startChild('child op',
          startTimestamp: startTimeForSpan2) as SentrySpan;
      final wrapper2 = LegacyInstrumentationSpan(span2);

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

      await sut.startTracking(wrapper1);
      await sut.startTracking(wrapper2);
      expect(sut.activeSpans, containsAll([wrapper1, wrapper2]));

      await sut.finishTracking(wrapper2, endTimeForSpan2);
      await sut.finishTracking(wrapper1, endTimeForSpan1);

      expect(tracer.data[SpanDataConvention.totalFrames], 10);
      expect(tracer.data[SpanDataConvention.slowFrames], 2);
      expect(tracer.data[SpanDataConvention.frozenFrames], 1);
      expect(tracer.data[SpanDataConvention.framesDelay], 500);
      expect(tracer.measurements[SentryMeasurement.totalFramesName]?.value, 10);
      expect(tracer.measurements[SentryMeasurement.slowFramesName]?.value, 2);
      expect(tracer.measurements[SentryMeasurement.frozenFramesName]?.value, 1);
      expect(
          tracer.measurements[SentryMeasurement.framesDelayName]?.value, 500);

      expect(span2.data[SpanDataConvention.totalFrames], 5);
      expect(span2.data[SpanDataConvention.slowFrames], 1);
      expect(span2.data[SpanDataConvention.frozenFrames], 3);
      expect(span2.data[SpanDataConvention.framesDelay], 400);

      expect(sut.activeSpans, isEmpty);
    });
  });

  group('SpanFrameMetricsCollector with StreamingInstrumentationSpan', () {
    test('filters out non-recording SentrySpanV2', () async {
      final sut = fixture.getSut();
      final noopSpan = NoOpSentrySpanV2();
      final wrapper = StreamingInstrumentationSpan(noopSpan);

      await sut.startTracking(wrapper);

      expect(sut.activeSpans, isEmpty);
      expect(fixture.resumeFrameTrackingCalledCount, 0);
    });

    test('tracks streaming spans and applies attributes', () async {
      final sut = fixture.getSut();
      final span = RecordingSentrySpanV2.root(
        name: 'test-op',
        traceId: SentryId.newId(),
        onSpanEnd: (_) async {},
        clock: fixture.options.clock,
        dscCreator: (span) => SentryTraceContextHeader(span.traceId, 'key'),
        samplingDecision: SentryTracesSamplingDecision(true),
      );
      final wrapper = StreamingInstrumentationSpan(span);
      final startTime = span.startTimestamp;
      final endTime = startTime.add(Duration(seconds: 1));

      final metrics = SpanFrameMetrics(
        totalFrameCount: 15,
        slowFrameCount: 3,
        frozenFrameCount: 2,
        framesDelay: 600,
      );
      when(fixture.mockFrameTracker.getFrameMetrics(
        spanStartTimestamp: startTime,
        spanEndTimestamp: endTime,
      )).thenReturn(metrics);

      await sut.startTracking(wrapper);
      expect(sut.activeSpans, contains(wrapper));
      expect(fixture.resumeFrameTrackingCalledCount, 1);

      await sut.finishTracking(wrapper, endTime);

      expect(
          span.attributes[SemanticAttributesConstants.framesTotal]?.value, 15);
      expect(span.attributes[SemanticAttributesConstants.framesSlow]?.value, 3);
      expect(
          span.attributes[SemanticAttributesConstants.framesFrozen]?.value, 2);
      expect(
          span.attributes[SemanticAttributesConstants.framesDelay]?.value, 600);
      expect(sut.activeSpans, isEmpty);
    });

    test('handles multiple concurrent streaming spans', () async {
      final sut = fixture.getSut();

      final span1 = RecordingSentrySpanV2.root(
        name: 'test-op-1',
        traceId: SentryId.newId(),
        onSpanEnd: (_) async {},
        clock: fixture.options.clock,
        dscCreator: (span) => SentryTraceContextHeader(span.traceId, 'key'),
        samplingDecision: SentryTracesSamplingDecision(true),
      );
      final wrapper1 = StreamingInstrumentationSpan(span1);
      final startTime1 = span1.startTimestamp;
      final endTime1 = startTime1.add(Duration(seconds: 1));

      final span2 = RecordingSentrySpanV2.root(
        name: 'test-op-2',
        traceId: SentryId.newId(),
        onSpanEnd: (_) async {},
        clock: fixture.options.clock,
        dscCreator: (span) => SentryTraceContextHeader(span.traceId, 'key'),
        samplingDecision: SentryTracesSamplingDecision(true),
      );
      final wrapper2 = StreamingInstrumentationSpan(span2);
      final startTime2 = span2.startTimestamp;
      final endTime2 = startTime2.add(Duration(seconds: 2));

      final metrics1 = SpanFrameMetrics(
        totalFrameCount: 10,
        slowFrameCount: 1,
        frozenFrameCount: 0,
        framesDelay: 100,
      );
      when(fixture.mockFrameTracker.getFrameMetrics(
        spanStartTimestamp: startTime1,
        spanEndTimestamp: endTime1,
      )).thenReturn(metrics1);

      final metrics2 = SpanFrameMetrics(
        totalFrameCount: 20,
        slowFrameCount: 4,
        frozenFrameCount: 2,
        framesDelay: 800,
      );
      when(fixture.mockFrameTracker.getFrameMetrics(
        spanStartTimestamp: startTime2,
        spanEndTimestamp: endTime2,
      )).thenReturn(metrics2);

      await sut.startTracking(wrapper1);
      await sut.startTracking(wrapper2);
      expect(sut.activeSpans, containsAll([wrapper1, wrapper2]));

      await sut.finishTracking(wrapper1, endTime1);
      await sut.finishTracking(wrapper2, endTime2);

      expect(
          span1.attributes[SemanticAttributesConstants.framesTotal]?.value, 10);
      expect(
          span1.attributes[SemanticAttributesConstants.framesSlow]?.value, 1);
      expect(
          span1.attributes[SemanticAttributesConstants.framesFrozen]?.value, 0);
      expect(span1.attributes[SemanticAttributesConstants.framesDelay]?.value,
          100);

      expect(
          span2.attributes[SemanticAttributesConstants.framesTotal]?.value, 20);
      expect(
          span2.attributes[SemanticAttributesConstants.framesSlow]?.value, 4);
      expect(
          span2.attributes[SemanticAttributesConstants.framesFrozen]?.value, 2);
      expect(span2.attributes[SemanticAttributesConstants.framesDelay]?.value,
          800);

      expect(sut.activeSpans, isEmpty);
    });
  });

  group('SpanFrameMetricsCollector common behavior', () {
    test('clear() clears activeSpans and frame tracker', () async {
      final sut = fixture.getSut();
      final span = MockSentrySpan();
      final wrapper = LegacyInstrumentationSpan(span);
      await sut.startTracking(wrapper);

      sut.clear();

      expect(sut.activeSpans, isEmpty);
      verify(fixture.mockFrameTracker.clear()).called(1);
      expect(fixture.pauseFrameTrackingCalledCount, 1);
    });

    test('clears tracker when activeSpans becomes empty', () async {
      final sut = fixture.getSut();
      final span = MockSentrySpan();
      final wrapper = LegacyInstrumentationSpan(span);
      final startTime = fixture.options.clock();
      final endTime = startTime.add(Duration(seconds: 1));
      when(span.startTimestamp).thenReturn(startTime);
      when(fixture.mockFrameTracker.getFrameMetrics(
              spanStartTimestamp: startTime, spanEndTimestamp: endTime))
          .thenReturn(null);

      await sut.startTracking(wrapper);
      await sut.finishTracking(wrapper, endTime);

      verify(fixture.mockFrameTracker.clear()).called(1);
      expect(fixture.pauseFrameTrackingCalledCount, 1);
    });

    test('removes irrelevant frames when spans remain', () async {
      final sut = fixture.getSut();
      final span1 = MockSentrySpan();
      final span2 = MockSentrySpan();
      final wrapper1 = LegacyInstrumentationSpan(span1);
      final wrapper2 = LegacyInstrumentationSpan(span2);

      final startTime = fixture.options.clock();
      final endTime = startTime.add(Duration(seconds: 1));
      final startTime2 = startTime.add(Duration(seconds: 2));
      when(span1.startTimestamp).thenReturn(startTime);
      when(span2.startTimestamp).thenReturn(startTime2);
      when(fixture.mockFrameTracker.getFrameMetrics(
              spanStartTimestamp: startTime, spanEndTimestamp: endTime))
          .thenReturn(null);

      await sut.startTracking(wrapper1);
      await sut.startTracking(wrapper2);

      await sut.finishTracking(wrapper1, endTime);

      verifyNever(fixture.mockFrameTracker.clear());
      expect(fixture.pauseFrameTrackingCalledCount, 0);
      verify(fixture.mockFrameTracker.removeIrrelevantFrames(startTime2))
          .called(1);
    });

    test('correctly removes span using wrapper equality', () async {
      final sut = fixture.getSut();
      fixture.options.tracesSampleRate = 1.0;
      final hub = Hub(fixture.options);
      final startTime = fixture.options.clock();
      final endTime = startTime.add(Duration(seconds: 1));

      final tracer = SentryTracer(SentryTransactionContext('name', 'op'), hub,
          startTimestamp: startTime);
      final span = SentrySpan(tracer, SentrySpanContext(operation: 'op'), hub,
          startTimestamp: startTime, isRootSpan: true);

      final wrapper1 = LegacyInstrumentationSpan(span);
      await sut.startTracking(wrapper1);
      expect(sut.activeSpans, contains(wrapper1));

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

      final wrapper2 = LegacyInstrumentationSpan(span);
      await sut.finishTracking(wrapper2, endTime);

      expect(sut.activeSpans, isEmpty);
      expect(tracer.data[SpanDataConvention.totalFrames], 10);
    });

    test('correctly removes streaming span using wrapper equality', () async {
      final sut = fixture.getSut();

      final span = RecordingSentrySpanV2.root(
        name: 'test-op',
        traceId: SentryId.newId(),
        onSpanEnd: (_) async {},
        clock: fixture.options.clock,
        dscCreator: (span) => SentryTraceContextHeader(span.traceId, 'key'),
        samplingDecision: SentryTracesSamplingDecision(true),
      );
      final startTime = span.startTimestamp;
      final endTime = startTime.add(Duration(seconds: 1));

      final wrapper1 = StreamingInstrumentationSpan(span);
      await sut.startTracking(wrapper1);
      expect(sut.activeSpans, contains(wrapper1));

      final metrics = SpanFrameMetrics(
        totalFrameCount: 15,
        slowFrameCount: 3,
        frozenFrameCount: 2,
        framesDelay: 600,
      );
      when(fixture.mockFrameTracker.getFrameMetrics(
        spanStartTimestamp: startTime,
        spanEndTimestamp: endTime,
      )).thenReturn(metrics);

      final wrapper2 = StreamingInstrumentationSpan(span);
      await sut.finishTracking(wrapper2, endTime);

      expect(sut.activeSpans, isEmpty);
      expect(
          span.attributes[SemanticAttributesConstants.framesTotal]?.value, 15);
    });

    test('handles unknown InstrumentationSpan types gracefully', () async {
      final sut = fixture.getSut();
      final unknownSpan = UnknownInstrumentationSpan();

      await sut.startTracking(unknownSpan);
      expect(sut.activeSpans, contains(unknownSpan));

      final startTime = unknownSpan.startTimestamp;
      final endTime = startTime.add(Duration(seconds: 1));
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

      await sut.finishTracking(unknownSpan, endTime);

      expect(sut.activeSpans, isEmpty);
    });

    test('handles error in frame tracker gracefully', () async {
      final sut = fixture.getSut();
      final span = MockSentrySpan();
      final wrapper = LegacyInstrumentationSpan(span);
      final startTime = fixture.options.clock();
      final endTime = startTime.add(Duration(seconds: 1));
      when(span.startTimestamp).thenReturn(startTime);
      when(fixture.mockFrameTracker.getFrameMetrics(
              spanStartTimestamp: startTime, spanEndTimestamp: endTime))
          .thenThrow(Exception('Frame tracker error'));

      await sut.startTracking(wrapper);
      await sut.finishTracking(wrapper, endTime);

      verify(fixture.mockFrameTracker.clear()).called(1);
      expect(sut.activeSpans, isEmpty);
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
      mockFrameTracker,
      resumeFrameTracking: () => resumeFrameTrackingCalledCount += 1,
      pauseFrameTracking: () => pauseFrameTrackingCalledCount += 1,
    );
  }
}

// Mock unknown span type for testing
class UnknownInstrumentationSpan implements InstrumentationSpan {
  final DateTime _startTimestamp = DateTime.now();

  @override
  bool get isRecording => true;

  @override
  DateTime get startTimestamp => _startTimestamp;

  @override
  Future<void> finish({SpanStatus? status, DateTime? endTimestamp}) async {}

  @override
  void setData(String key, value) {}

  @override
  void setTag(String key, String value) {}

  @override
  SpanStatus? get status => null;

  @override
  set status(SpanStatus? status) {}

  @override
  dynamic get throwable => null;

  @override
  set throwable(throwable) {}

  @override
  String? get origin => null;

  @override
  set origin(String? origin) {}

  @override
  SentryTraceHeader toSentryTrace() => generateSentryTraceHeader(
        traceId: SentryId.newId(),
        spanId: SpanId.newId(),
        sampled: false,
      );

  @override
  SentryBaggageHeader? toBaggageHeader() => null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnknownInstrumentationSpan && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}
