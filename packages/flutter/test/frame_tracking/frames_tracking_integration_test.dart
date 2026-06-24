// ignore_for_file: invalid_use_of_internal_member, experimental_member_use
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/binding_wrapper.dart';
import 'package:sentry_flutter/src/frames_tracking/span_frame_metrics_collector.dart';
import 'package:sentry_flutter/src/integrations/frames_tracking_integration.dart';

import '../binding.dart';
import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  SentryAutomatedTestWidgetsFlutterBinding.ensureInitialized();

  late SentryFlutterOptions options;
  late FramesTrackingIntegration integration;
  late SentryWidgetsBindingMixin? widgetsBinding;

  Future<void> fromWorkingState(
    SentryFlutterOptions options, {
    bool? disableTracing,
    bool? disableFramesTracking,
    bool? setInvalidRefreshRate,
    bool? setIncompatibleBinding,
  }) async {
    options.tracesSampleRate = 1.0;
    if (disableTracing == true) {
      options.tracesSampleRate = null;
    }

    if (disableFramesTracking == true) {
      options.enableFramesTracking = false;
    }

    final mockNativeBinding = MockSentryNativeBinding();
    when(mockNativeBinding.displayRefreshRate())
        .thenAnswer((_) async => setInvalidRefreshRate == true ? 0 : 60);

    if (setIncompatibleBinding == true) {
      final mockBindingWrapper = MockBindingWrapper();
      when(mockBindingWrapper.instance).thenReturn(MockWidgetsFlutterBinding());
      options.bindingUtils = mockBindingWrapper;
    }

    integration = FramesTrackingIntegration(mockNativeBinding);

    // hub is not used in the integration so it doesnt matter what we pass here
    await integration.call(Hub(options), options);
  }

  bool isFramesTrackingInitialized(SentryWidgetsBindingMixin binding) {
    return binding.options != null &&
        binding.onDelayedFrame != null &&
        binding.expectedFrameDuration != null;
  }

  void assertInitFailure() {
    if (widgetsBinding != null) {
      expect(isFramesTrackingInitialized(widgetsBinding!), isFalse);
    }
    // Both streaming and static lifecycles use lifecycle callbacks, not performance collectors
    expect(options.lifecycleRegistry.lifecycleCallbacks, isEmpty);
  }

  setUp(() {
    options = defaultTestOptions();
    widgetsBinding = options.bindingUtils.instance is SentryWidgetsBindingMixin
        ? options.bindingUtils.instance as SentryWidgetsBindingMixin
        : null;
  });

  tearDown(() {
    integration.close();
  });

  test('adds integration to SDK list', () async {
    await fromWorkingState(options);

    expect(options.sdk.integrations,
        contains(FramesTrackingIntegration.integrationName));
  });

  test('properly cleans up resources on close - streaming', () async {
    options.traceLifecycle = SentryTraceLifecycle.stream;
    await fromWorkingState(options);

    expect(isFramesTrackingInitialized(widgetsBinding!), isTrue);
    expect(
      options.lifecycleRegistry.lifecycleCallbacks.containsKey(OnSpanStartV2),
      isTrue,
    );
    expect(
      options.lifecycleRegistry.lifecycleCallbacks.containsKey(OnProcessSpan),
      isTrue,
    );

    integration.close();

    expect(isFramesTrackingInitialized(widgetsBinding!), isFalse);
    expect(
      options.lifecycleRegistry.lifecycleCallbacks[OnSpanStartV2],
      isEmpty,
    );
    expect(
      options.lifecycleRegistry.lifecycleCallbacks[OnProcessSpan],
      isEmpty,
    );
  });

  test('properly cleans up resources on close - static', () async {
    options.traceLifecycle = SentryTraceLifecycle.static;
    await fromWorkingState(options);

    expect(isFramesTrackingInitialized(widgetsBinding!), isTrue);
    expect(
      options.lifecycleRegistry.lifecycleCallbacks.containsKey(OnSpanStart),
      isTrue,
    );
    expect(
      options.lifecycleRegistry.lifecycleCallbacks.containsKey(OnSpanFinish),
      isTrue,
    );

    integration.close();

    expect(isFramesTrackingInitialized(widgetsBinding!), isFalse);
    expect(
      options.lifecycleRegistry.lifecycleCallbacks[OnSpanStart],
      isEmpty,
    );
    expect(
      options.lifecycleRegistry.lifecycleCallbacks[OnSpanFinish],
      isEmpty,
    );
  });

  // multiple conditions need to be true to allow frames tracking
  // if one of those fails then the integration shouldn't proceed
  group('fails to initializes frames tracking', () {
    test('when tracing is disabled', () async {
      await fromWorkingState(options, disableTracing: true);

      assertInitFailure();
    });

    test('when refresh rate is invalid', () async {
      await fromWorkingState(options, setInvalidRefreshRate: true);

      assertInitFailure();
    });

    test('when binding is not compatible', () async {
      await fromWorkingState(options, setIncompatibleBinding: true);

      assertInitFailure();
    });

    test('when frames tracking option is disabled', () async {
      await fromWorkingState(options, disableFramesTracking: true);

      assertInitFailure();
    });
  });

  group('with streaming lifecycle', () {
    setUp(() {
      options.traceLifecycle = SentryTraceLifecycle.stream;
    });

    test('registers lifecycle callbacks', () async {
      await fromWorkingState(options);

      expect(
        options.lifecycleRegistry.lifecycleCallbacks.containsKey(OnSpanStartV2),
        isTrue,
      );
      expect(
        options.lifecycleRegistry.lifecycleCallbacks.containsKey(OnProcessSpan),
        isTrue,
      );
    });
  });

  group('with static lifecycle', () {
    setUp(() {
      options.traceLifecycle = SentryTraceLifecycle.static;
    });

    test('registers lifecycle callbacks', () async {
      await fromWorkingState(options);

      expect(
        options.lifecycleRegistry.lifecycleCallbacks.containsKey(OnSpanStart),
        isTrue,
      );
      expect(
        options.lifecycleRegistry.lifecycleCallbacks.containsKey(OnSpanFinish),
        isTrue,
      );
    });

    test('cleans up when span with null endTimestamp is last active span',
        () async {
      await fromWorkingState(options);

      final mockFrameTracker = MockSentryDelayedFramesTracker();
      int pauseFrameTrackingCalledCount = 0;

      // Create a new collector with our own counters
      final testCollector = SpanFrameMetricsCollector(
        mockFrameTracker,
        resumeFrameTracking: () => widgetsBinding!.resumeTrackingFrames(),
        pauseFrameTracking: () {
          pauseFrameTrackingCalledCount++;
          widgetsBinding!.pauseTrackingFrames();
        },
      );

      // Simulate a span starting
      final hub = Hub(options);
      final tracer = hub.startTransaction(
        'test_transaction',
        'test_operation',
        bindToScope: true,
        startTimestamp: options.clock(),
      ) as SentryTracer;

      final span = tracer.startChild(
        'child_operation',
        description: 'Child span',
        startTimestamp: options.clock(),
      ) as SentrySpan;

      final wrapped = LegacyInstrumentationSpan(span);
      await testCollector.startTracking(wrapped);

      expect(testCollector.activeSpans, contains(wrapped));

      // Simulate what happens with null endTimestamp (integration code path)
      testCollector.activeSpans.remove(wrapped);
      if (testCollector.activeSpans.isEmpty) {
        testCollector.clear();
      }

      // Verify cleanup: pauseFrameTracking should be called when activeSpans becomes empty
      expect(testCollector.activeSpans, isEmpty);
      expect(pauseFrameTrackingCalledCount, 1);
      verify(mockFrameTracker.clear()).called(1);
    });
  });

  group('with streaming lifecycle', () {
    setUp(() {
      options.traceLifecycle = SentryTraceLifecycle.stream;
    });

    test('cleans up when span with null endTimestamp is last active span',
        () async {
      await fromWorkingState(options);

      final mockFrameTracker = MockSentryDelayedFramesTracker();
      int pauseFrameTrackingCalledCount = 0;

      // Create a new collector with our own counters
      final testCollector = SpanFrameMetricsCollector(
        mockFrameTracker,
        resumeFrameTracking: () => widgetsBinding!.resumeTrackingFrames(),
        pauseFrameTracking: () {
          pauseFrameTrackingCalledCount++;
          widgetsBinding!.pauseTrackingFrames();
        },
      );

      // Simulate a span starting
      final hub = Hub(options);
      final span = hub.startInactiveSpan('test_span') as RecordingSentrySpanV2;

      final wrapped = StreamingInstrumentationSpan(span);
      await testCollector.startTracking(wrapped);

      expect(testCollector.activeSpans, contains(wrapped));

      // Simulate what happens with null endTimestamp (integration code path)
      testCollector.activeSpans.remove(wrapped);
      if (testCollector.activeSpans.isEmpty) {
        testCollector.clear();
      }

      // Verify cleanup: pauseFrameTracking should be called when activeSpans becomes empty
      expect(testCollector.activeSpans, isEmpty);
      expect(pauseFrameTrackingCalledCount, 1);
      verify(mockFrameTracker.clear()).called(1);
    });
  });
}
