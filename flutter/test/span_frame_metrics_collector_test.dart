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
    sut.frameDurations[DateTime.now()] = 1;
    final mockSpan = MockSentrySpan();
    when(mockSpan.startTimestamp).thenReturn(DateTime.now());

    sut.onSpanStarted(mockSpan);
    sut.clear();

    expect(sut.frameDurations, isEmpty);
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
    final startTimestamp = DateTime.now().toUtc();
    final endTimestamp =
        startTimestamp.add(Duration(milliseconds: 800)).toUtc();

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

    sut.frameDurations[spanStartTimestamp.subtract(Duration(seconds: 5))] = 1;
    sut.frameDurations[spanStartTimestamp.subtract(Duration(seconds: 3))] = 1;
    sut.frameDurations[spanStartTimestamp.add(Duration(seconds: 4))] = 1;

    await sut.onSpanFinished(span1, spanEndTimestamp);

    expect(sut.frameDurations, hasLength(1));
    expect(sut.frameDurations.keys.first,
        spanStartTimestamp.add(Duration(seconds: 4)));
  });

  test(
      'starting and finishing a span calculates and attaches frame metrics to span',
      () async {
    final sut = fixture.sut;
    fixture.options.tracesSampleRate = 1.0;
    fixture.options.addPerformanceCollector(sut);
    final startTimestamp = DateTime.now();
    final endTimestamp = startTimestamp.add(Duration(milliseconds: 800));

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

  test('negative values in frame metrics leads to empty map', () async {
    final sut = fixture.sut;
    fixture.options.tracesSampleRate = 1.0;
    fixture.options.addPerformanceCollector(sut);
    const displayRefreshRate = 60;

    final tracer = MockSentryTracer();

    final startTimestamp = DateTime.now();
    when(tracer.startTimestamp).thenReturn(startTimestamp);
    when(tracer.context).thenReturn(SentryTransactionContext('name', 'op'));

    sut.frameDurations[startTimestamp.add(Duration(milliseconds: 1))] = 500;

    final frameMetrics = sut.calculateFrameMetrics(tracer,
        startTimestamp.add(Duration(milliseconds: 10)), displayRefreshRate);

    expect(frameMetrics.isEmpty, isTrue);
  });

  test('calculates frame metrics correctly for multiple simultaneous spans',
      () async {
    final sut = fixture.sut;
    fixture.options.tracesSampleRate = 1.0;
    fixture.options.addPerformanceCollector(sut);
    final startTimestamp = DateTime.now();
    final endTimestamp = startTimestamp.add(Duration(milliseconds: 800));

    final tracer = SentryTracer(
        SentryTransactionContext('name1', 'op1'), fixture.hub,
        startTimestamp: startTimestamp);

    final child = tracer.startChild('child') as SentrySpan;

    await Future<void>.delayed(Duration(milliseconds: 500));
    await child.finish(endTimestamp: endTimestamp);
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
