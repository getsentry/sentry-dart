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

  const framesDelayRange = 30;
  const totalFramesRange = 2;

  setUp(() {
    fixture = Fixture();
    WidgetsFlutterBinding.ensureInitialized();

    when(fixture.mockSentryNative.displayRefreshRate()).thenAnswer((_) async => 60);
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

    when(fixture.mockSentryNative.displayRefreshRate()).thenAnswer((_) async => null);

    final tracer = SentryTracer(
        SentryTransactionContext('name', 'op', description: 'tracerDesc'),
        fixture.hub);

    await Future<void>.delayed(Duration(milliseconds: 800));

    await tracer.finish();

    expect(tracer.data['frames.slow'], 2);
    expect(tracer.data['frames.frozen'], 1);
    expect(
        tracer.data['frames.delay'], _isWithinRange(expectedFramesDelay, framesDelayRange));
    expect(tracer.data['frames.total'], _isWithinRange(expectedTotalFrames, totalFramesRange));
  });

  test('frame tracking collects frame durations within expected range',
      () async {
    final sut = fixture.sut;

    sut.startFrameTracking();
    await Future<void>.delayed(Duration(seconds: 1));

    final expectedDurations = fakeFrameDurations;
    final actualDurations = sut.frameDurations.values.toList();
    expect(
        actualDurations,
        containsAllInOrder(expectedDurations
            .map((duration) => _isWithinRange(duration.inMilliseconds))));
  });

  test('onSpanFinished removes frames older than span start timestamp',
      () async {
    // We add 2 spans here because onSpanFinished also removes the span from the
    // internal list and if that is empty then we just clear the whole tracker
    // So we need multiple spans to test the removal of frames
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

    final tracer = SentryTracer(
        SentryTransactionContext('name', 'op', description: 'tracerDesc'),
        fixture.hub);
    final child =
        tracer.startChild('child', description: 'description') as SentrySpan;

    await Future<void>.delayed(Duration(milliseconds: 800));

    await child.finish();
    await tracer.finish();

    expect(tracer.data['frames.slow'], 2);
    expect(tracer.data['frames.frozen'], 1);
    expect(
        tracer.data['frames.delay'], _isWithinRange(expectedFramesDelay, framesDelayRange));
    expect(tracer.data['frames.total'], _isWithinRange(expectedTotalFrames, totalFramesRange));

    expect(tracer.measurements['frames_delay']!.value,
        _isWithinRange(expectedFramesDelay, 10));
    expect(tracer.measurements['frames_total']!.value,
        _isWithinRange(expectedTotalFrames, totalFramesRange));
    expect(tracer.measurements['frames_slow']!.value, 2);
    expect(tracer.measurements['frames_frozen']!.value, 1);

    expect(child.data['frames.slow'], 2);
    expect(child.data['frames.frozen'], 1);
    expect(child.data['frames.delay'], _isWithinRange(expectedFramesDelay, framesDelayRange));
    expect(child.data['frames.total'], _isWithinRange(expectedTotalFrames, totalFramesRange));
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

    final tracer1 =
        SentryTracer(SentryTransactionContext('name1', 'op1'), fixture.hub);
    final tracer2 =
        SentryTracer(SentryTransactionContext('name2', 'op2'), fixture.hub);

    await Future<void>.delayed(Duration(milliseconds: 800));
    await tracer1.finish();

    await Future<void>.delayed(Duration(milliseconds: 800));
    await tracer2.finish();

    expect(tracer1.data['frames.slow'], 2);
    expect(tracer1.data['frames.frozen'], 1);
    expect(
        tracer1.data['frames.delay'], _isWithinRange(expectedFramesDelay, framesDelayRange));
    expect(
        tracer1.data['frames.total'], _isWithinRange(expectedTotalFrames, totalFramesRange));

    expect(tracer1.measurements['frames_delay']!.value,
        _isWithinRange(expectedFramesDelay, 10));
    expect(tracer1.measurements['frames_total']!.value,
        _isWithinRange(expectedTotalFrames, totalFramesRange));
    expect(tracer1.measurements['frames_slow']!.value, 2);
    expect(tracer1.measurements['frames_frozen']!.value, 1);

    expect(tracer2.data['frames.slow'], 2);
    expect(tracer2.data['frames.frozen'], 1);
    expect(
        tracer2.data['frames.delay'], _isWithinRange(expectedFramesDelay, 10));
    // expect(tracer2.data['frames.total'], _isWithinRange(expectedTotalFrames, totalFramesRange));

    expect(tracer2.measurements['frames_delay']!.value,
        _isWithinRange(expectedFramesDelay, 10));
    // expect(tracer2.measurements['frames_total']!.value,
    //     _isWithinRange(expectedTotalFrames, totalFramesRange));
    expect(tracer2.measurements['frames_slow']!.value, 2);
    expect(tracer2.measurements['frames_frozen']!.value, 1);
  });

  test('frame tracker is paused after finishing a span', () async {
    final sut = fixture.sut;
    fixture.options.tracesSampleRate = 1.0;
    fixture.options.addPerformanceCollector(sut);

    final tracer =
        SentryTracer(SentryTransactionContext('name', 'op'), fixture.hub);

    await Future<void>.delayed(Duration(milliseconds: 800));

    await tracer.finish();

    expect(sut.isTrackingPaused, isTrue);
  });
}

Matcher _isWithinRange(int expected, [int delta = 5]) => allOf(
      greaterThanOrEqualTo(expected - delta),
      lessThanOrEqualTo(expected + delta),
    );

class Fixture {
  final options = SentryFlutterOptions(dsn: fakeDsn);
  late final hub = Hub(options);
  final fakeFrameCallbackHandler = FakeFrameCallbackHandler();
  final mockSentryNative = MockSentryNativeBinding();

  SpanFrameMetricsCollector get sut => SpanFrameMetricsCollector(options,
      frameCallbackHandler: fakeFrameCallbackHandler, native: mockSentryNative);
}
