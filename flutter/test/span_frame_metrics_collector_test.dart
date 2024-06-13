import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/sentry_io.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/span_frame_metrics_collector.dart';

import 'fake_frame_callback_handler.dart';
import 'mocks.dart';

// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

import 'mocks.mocks.dart';

void main() {
  final fixture = Fixture();

  setUp(() {
    WidgetsFlutterBinding.ensureInitialized();
  });

  test('startFrameCollector collects frame durations within expected range',
      () async {
    final sut = fixture.sut;

    sut.startFrameCollector();
    await Future<void>.delayed(Duration(seconds: 1));

    final expectedDurations = fixture.fakeFrameCallbackHandler.frameDurations;
    final actualDurations = sut.frames.values.toList();
    expect(
        actualDurations,
        containsAllInOrder(expectedDurations
            .map((duration) => _isWithinRange(duration.inMilliseconds))));
  });

  test('captureFrameMetrics calculates frame metrics correctly for trace',
      () async {
    final sut = fixture.sut;
    fixture.options.tracesSampleRate = 1.0;
    fixture.options.addPerformanceCollector(sut);

    final tracer =
        SentryTracer(SentryTransactionContext('name', 'op'), fixture.hub);
    final child = tracer.startChild('child') as SentrySpan;

    await Future<void>.delayed(Duration(milliseconds: 800));

    await child.finish();
    await tracer.finish();

    // The expected delay is based on the frame durations in the fake frame callback handler
    // If the values in the fake frame callback handler change, this value will need to be updated
    const expectedFramesDelay = 722;

    // The expected total frames is based on the span duration and the slow and frozen frames
    const expectedTotalFrames = 4;

    expect(tracer.data['frames.slow'], 2);
    expect(tracer.data['frames.frozen'], 1);
    expect(
        tracer.data['frames.delay'], _isWithinRange(expectedFramesDelay, 10));
    expect(tracer.data['frames.total'], _isWithinRange(expectedTotalFrames, 2));

    expect(tracer.measurements['frames_delay']!.value,
        _isWithinRange(expectedFramesDelay, 10));
    expect(tracer.measurements['frames_total']!.value,
        _isWithinRange(expectedTotalFrames, 2));
    expect(tracer.measurements['frames_slow']!.value, 2);
    expect(tracer.measurements['frames_frozen']!.value, 1);

    expect(child.data['frames.slow'], 2);
    expect(child.data['frames.frozen'], 1);
    expect(child.data['frames.delay'], _isWithinRange(expectedFramesDelay, 10));
    expect(child.data['frames.total'], _isWithinRange(expectedTotalFrames, 2));
  });

  test('frame tracker is paused after finishing a span', () async {
    final sut = fixture.sut;
    fixture.options.tracesSampleRate = 1.0;
    fixture.options.addPerformanceCollector(sut);

    final tracer =
        SentryTracer(SentryTransactionContext('name', 'op'), fixture.hub);

    await Future<void>.delayed(Duration(milliseconds: 800));

    await tracer.finish();

    expect(sut.isFrameTrackingPaused, isTrue);
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

  SpanFrameMetricsCollector get sut => SpanFrameMetricsCollector(options,
      frameCallbackHandler: fakeFrameCallbackHandler);
}
