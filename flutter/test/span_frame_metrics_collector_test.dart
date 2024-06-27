import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/span_frame_metrics_collector.dart';

import 'fake_frame_callback_handler.dart';
import 'mocks.dart';

// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

import 'mocks.mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
    WidgetsFlutterBinding.ensureInitialized();

    when(fixture.mockSentryNative.displayRefreshRate())
        .thenAnswer((_) async => 60);
  });

  test('clear() clears frames, running spans and pauses frame tracking', () {
    final sut = fixture.sut;
    sut.frames[DateTime.now()] = 1;
    final mockSpan = MockSentrySpan();
    when(mockSpan.startTimestamp).thenReturn(DateTime.now());

    sut.onSpanStarted(mockSpan);
    sut.clear();

    expect(sut.frames, isEmpty);
    expect(sut.activeSpans, isEmpty);
    expect(sut.isTrackingPaused, isTrue);
  });

  test('does not start frame tracking if frames tracking is disabled', () {
    final sut = fixture.sut;
    fixture.options.enableFramesTracking = false;

    final span = MockSentrySpan();
    sut.onSpanStarted(span);

    expect(sut.isTrackingRegistered, isFalse);
  });

  test(
      'captures metrics with display refresh rate of 60 if native refresh rate is null',
      () async {
    final sut = fixture.sut;
    fixture.options.tracesSampleRate = 1.0;
    fixture.options.addPerformanceCollector(sut);
    final startTimestamp = DateTime.now();
    final endTimestamp =
        startTimestamp.add(Duration(milliseconds: 1000)).toUtc();

    when(fixture.mockSentryNative.displayRefreshRate())
        .thenAnswer((_) async => null);

    final tracer = SentryTracer(
        SentryTransactionContext('name', 'op', description: 'tracerDesc'),
        fixture.hub,
        startTimestamp: startTimestamp);

    await Future<void>.delayed(Duration(milliseconds: 500));
    await tracer.finish(endTimestamp: endTimestamp);

    expect(tracer.data['frames.slow'], expectedSlowFrames);
    expect(tracer.data['frames.frozen'], expectedFrozenFrames);
    expect(tracer.data['frames.delay'], expectedFramesDelay);
    expect(tracer.data['frames.total'], expectedTotalFrames);
  });

  test('onSpanFinished removes frames older than span start timestamp',
      () async {
    // Using multiple spans to test frame removal. When the last span is finished,
    // the tracker clears all data, so we need at least two spans to observe partial removal.
    final sut = fixture.sut;
    final span1 = MockSentrySpan();
    final span2 = MockSentrySpan();
    final spanStartTimestamp = DateTime.now();
    final spanEndTimestamp = spanStartTimestamp.add(Duration(seconds: 1));

    when(span1.isRootSpan).thenReturn(false);
    when(span1.startTimestamp).thenReturn(spanStartTimestamp);
    when(span1.context).thenReturn(SentrySpanContext(operation: 'op'));

    when(span2.isRootSpan).thenReturn(false);
    when(span2.startTimestamp)
        .thenReturn(spanStartTimestamp.add(Duration(seconds: 2)));
    when(span2.context).thenReturn(SentrySpanContext(operation: 'op'));

    sut.activeSpans.add(span1);
    sut.activeSpans.add(span2);

    sut.frames[spanStartTimestamp.subtract(Duration(seconds: 5))] = 1;
    sut.frames[spanStartTimestamp.subtract(Duration(seconds: 3))] = 1;
    sut.frames[spanStartTimestamp.add(Duration(seconds: 4))] = 1;

    await sut.onSpanFinished(span1, spanEndTimestamp);

    expect(sut.frames, hasLength(1));
    expect(sut.frames.keys.first, spanStartTimestamp.add(Duration(seconds: 4)));
  });

  test(
      'starting and finishing a span calculates and attaches frame metrics to span',
      () async {
    final sut = fixture.sut;
    fixture.options.tracesSampleRate = 1.0;
    fixture.options.addPerformanceCollector(sut);
    final startTimestamp = DateTime.now();
    final endTimestamp = startTimestamp.add(Duration(milliseconds: 1000));

    final tracer = SentryTracer(
        SentryTransactionContext('name1', 'op1'), fixture.hub,
        startTimestamp: startTimestamp);

    await Future<void>.delayed(Duration(milliseconds: 500));
    await tracer.finish(endTimestamp: endTimestamp);

    expect(tracer.data['frames.slow'], expectedSlowFrames);
    expect(tracer.data['frames.frozen'], expectedFrozenFrames);
    expect(tracer.data['frames.delay'], expectedFramesDelay);
    expect(tracer.data['frames.total'], expectedTotalFrames);

    expect(tracer.measurements['frames_delay']!.value, expectedFramesDelay);
    expect(tracer.measurements['frames_total']!.value, expectedTotalFrames);
    expect(tracer.measurements['frames_slow']!.value, expectedSlowFrames);
    expect(tracer.measurements['frames_frozen']!.value, expectedFrozenFrames);
  });

  test('frame fully contained in span should contribute to frame metrics', () {
    final sut = fixture.sut;
    final span = MockSentrySpan();

    final now = DateTime.now();
    when(span.startTimestamp).thenReturn(now);
    when(span.endTimestamp).thenReturn(now.add(Duration(milliseconds: 500)));
    sut.frames[now.add(Duration(milliseconds: 200))] = 100;

    final metrics = sut.calculateFrameMetrics(span, span.endTimestamp!, 60);

    expect(metrics['frames.total'], 26);
    expect(metrics['frames.slow'], 1);
    expect(metrics['frames.delay'], 84);
    expect(metrics['frames.frozen'], 0);
  });

  test('frame fully outside of span should not contribute to frame metrics',
      () {
    final sut = fixture.sut;
    final span = MockSentrySpan();

    final now = DateTime.now();
    when(span.startTimestamp).thenReturn(now);
    when(span.endTimestamp).thenReturn(now.add(Duration(milliseconds: 500)));
    sut.frames[now.subtract(Duration(milliseconds: 200))] = 100;

    final metrics = sut.calculateFrameMetrics(span, span.endTimestamp!, 60);

    expect(metrics['frames.total'], 31);
    expect(metrics['frames.slow'], 0);
    expect(metrics['frames.delay'], 0);
    expect(metrics['frames.frozen'], 0);
  });

  test(
      'frame partially contained in span (starts before span and ends within span) should contribute to frame metrics',
      () {
    final sut = fixture.sut;
    final span = MockSentrySpan();

    final now = DateTime.now();
    when(span.startTimestamp).thenReturn(now);
    when(span.endTimestamp).thenReturn(now.add(Duration(milliseconds: 500)));
    // 50ms before span starts and ends 50ms after span starts
    sut.frames[now.add(Duration(milliseconds: 50))] = 100;

    final metrics = sut.calculateFrameMetrics(span, span.endTimestamp!, 60);

    expect(metrics['frames.total'], 29);
    expect(metrics['frames.slow'], 1);
    expect(metrics['frames.delay'], 42);
    expect(metrics['frames.frozen'], 0);
  });

  test(
      'frame partially contained in span (starts withing span and ends after span end) should contribute to frame metrics',
      () {
    final sut = fixture.sut;
    final span = MockSentrySpan();

    final now = DateTime.now();
    when(span.startTimestamp).thenReturn(now);
    when(span.endTimestamp).thenReturn(now.add(Duration(milliseconds: 500)));
    sut.frames[now.add(Duration(milliseconds: 550))] = 100;

    final metrics = sut.calculateFrameMetrics(span, span.endTimestamp!, 60);

    expect(metrics['frames.total'], 29);
    expect(metrics['frames.slow'], 1);
    expect(metrics['frames.delay'], 42);
    expect(metrics['frames.frozen'], 0);
  });

  test('calculates frame metrics correctly for multiple simultaneous spans',
      () async {
    final sut = fixture.sut;
    fixture.options.tracesSampleRate = 1.0;
    fixture.options.addPerformanceCollector(sut);
    final startTimestamp = DateTime.now();
    final endTimestamp = startTimestamp.add(Duration(milliseconds: 1000));

    final tracer = SentryTracer(
        SentryTransactionContext('name1', 'op1'), fixture.hub,
        startTimestamp: startTimestamp);

    final child = tracer.startChild('child',
            startTimestamp: startTimestamp.add(Duration(milliseconds: 1)))
        as SentrySpan;

    await Future<void>.delayed(Duration(milliseconds: 500));
    await child.finish(endTimestamp: endTimestamp);

    await Future<void>.delayed(Duration(milliseconds: 500));
    await tracer.finish(endTimestamp: endTimestamp);

    expect(child.data['frames.slow'], expectedSlowFrames);
    expect(child.data['frames.frozen'], expectedFrozenFrames);
    expect(child.data['frames.delay'], expectedFramesDelay);
    expect(child.data['frames.total'], expectedTotalFrames);

    // total frames is hardcoded here since it depends on span duration as well
    // and we are deviating from the default 800ms to 1600ms for the whole transaction
    expect(tracer.data['frames.slow'], expectedSlowFrames);
    expect(tracer.data['frames.frozen'], expectedFrozenFrames);
    expect(tracer.data['frames.delay'], expectedFramesDelay);
    // expect(tracer.data['frames.total'], 54);
    expect(tracer.measurements['frames_delay']!.value, expectedFramesDelay);
    // expect(tracer.measurements['frames_total']!.value, 54);
    expect(tracer.measurements['frames_slow']!.value, expectedSlowFrames);
    expect(tracer.measurements['frames_frozen']!.value, expectedFrozenFrames);
  });

  test('frame tracker is paused after finishing a span', () async {
    final sut = fixture.sut;
    fixture.options.tracesSampleRate = 1.0;
    fixture.options.addPerformanceCollector(sut);

    final tracer =
        SentryTracer(SentryTransactionContext('name', 'op'), fixture.hub);

    await Future<void>.delayed(Duration(milliseconds: 100));
    await tracer.finish();

    expect(sut.isTrackingPaused, isTrue);
  });
}

class Fixture {
  final options = SentryFlutterOptions(dsn: fakeDsn);
  late final hub = Hub(options);
  final fakeFrameCallbackHandler = FakeFrameCallbackHandler();
  final mockSentryNative = MockSentryNativeBinding();

  SpanFrameMetricsCollector get sut => SpanFrameMetricsCollector(options,
      frameCallbackHandler: fakeFrameCallbackHandler,
      native: mockSentryNative,
      isTestMode: true);
}
