// ignore_for_file: invalid_use_of_internal_member
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/binding_wrapper.dart';
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
    expect(options.performanceCollectors, isEmpty);
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

  test('properly cleans up resources on close', () async {
    await fromWorkingState(options);

    expect(isFramesTrackingInitialized(widgetsBinding!), isTrue);
    expect(options.performanceCollectors, isNotEmpty);

    integration.close();

    expect(isFramesTrackingInitialized(widgetsBinding!), isFalse);
    expect(options.performanceCollectors, isEmpty);
  });

  group('succeeds to initialize frames tracking', () {
    late Hub hub;

    setUp(() async {
      hub = Hub(options);
      await fromWorkingState(options);
    });

    testWidgets('measures frames', (WidgetTester tester) async {
      SentryTracer? tracer;
      ISentrySpan? child;

      await tester.runAsync(() async {
        // Widget to be rendered
        Widget testWidget = MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                child: Text('Start Transaction'),
                onPressed: () {
                  tracer = hub.startTransaction(
                      'test_transaction', 'test_operation',
                      bindToScope: true,
                      startTimestamp: options.clock()) as SentryTracer;
                  child = tracer?.startChild('child_operation',
                      description: 'Child span',
                      startTimestamp: options.clock());
                },
              ),
            ),
          ),
        );

        await tester.pumpWidget(testWidget);
        await tester.tap(find.byType(ElevatedButton));

        // Ensure spans are created and frame tracking is active
        expect(tracer, isNotNull, reason: 'Tracer should be created after tapping button');
        expect(child, isNotNull, reason: 'Child span should be created after tapping button');
        
        // Give time for the SpanFrameMetricsCollector.onSpanStarted to activate tracking
        await tester.pump(Duration(milliseconds: 10));
        
        // Verify frame tracking is active
        expect(widgetsBinding!.options?.enableFramesTracking, isTrue);
        
        /// Generates 2 slow and 1 frozen frame for the child span
        Future<void> _simulateChildSpanFrames() async {
          // Simulate slow frame (100ms > 16.67ms expected frame duration)
          tester.binding.handleBeginFrame(Duration());
          await Future<void>.delayed(Duration(milliseconds: 100));
          tester.binding.handleDrawFrame();
          // Allow processing time
          await tester.pump(Duration.zero);

          // Simulate another slow frame
          tester.binding.handleBeginFrame(Duration());
          await Future<void>.delayed(Duration(milliseconds: 100));
          tester.binding.handleDrawFrame();
          await tester.pump(Duration.zero);

          // Simulate frozen frame (800ms > 700ms frozen threshold)
          tester.binding.handleBeginFrame(Duration());
          await Future<void>.delayed(Duration(milliseconds: 800));
          tester.binding.handleDrawFrame();
          await tester.pump(Duration.zero);
        }

        await _simulateChildSpanFrames();
        
        // Allow time for frame processing before finishing child span
        await tester.pump(Duration(milliseconds: 10));
        await child?.finish(endTimestamp: options.clock());

        /// Generates 3 slow and 1 frozen frame for the tracer
        /// However when asserting later, the tracer will also include the number
        /// of slow and frozen frames from the child span.
        Future<void> _simulateTracerFrames() async {
          // Simulate 3 slow frames
          for (int i = 0; i < 3; i++) {
            tester.binding.handleBeginFrame(Duration());
            await Future<void>.delayed(Duration(milliseconds: 100));
            tester.binding.handleDrawFrame();
            await tester.pump(Duration.zero);
          }

          // Simulate 1 frozen frame
          tester.binding.handleBeginFrame(Duration());
          await Future<void>.delayed(Duration(milliseconds: 800));
          tester.binding.handleDrawFrame();
          await tester.pump(Duration.zero);
        }

        await _simulateTracerFrames();
        
        // Allow time for frame processing before finishing tracer
        await tester.pump(Duration(milliseconds: 10));
        await tracer?.finish(endTimestamp: options.clock());

        // Allow time for span processing to complete
        await tester.pump(Duration(milliseconds: 10));

        expect(tracer, isNotNull);

        // Verify child span - add more detailed error messages
        final childSpan = tracer!.children.first;
        expect(childSpan.data['frames.slow'] as int?, 2, 
            reason: 'Child span should have 2 slow frames, but got ${childSpan.data['frames.slow']}. '
                   'Child span data: ${childSpan.data}');
        expect(childSpan.data['frames.frozen'] as int?, 1,
            reason: 'Child span should have 1 frozen frame, but got ${childSpan.data['frames.frozen']}. '
                   'Child span data: ${childSpan.data}');

        // Verify tracer - add more detailed error messages
        expect(tracer!.data['frames.slow'] as int?, 5,
            reason: 'Tracer should have 5 slow frames total, but got ${tracer!.data['frames.slow']}. '
                   'Tracer data: ${tracer!.data}');
        expect(tracer!.data['frames.frozen'] as int?, 2,
            reason: 'Tracer should have 2 frozen frames total, but got ${tracer!.data['frames.frozen']}. '
                   'Tracer data: ${tracer!.data}');
                   
        expect(
            (tracer!.measurements['frames_total'] as SentryMeasurement?)?.value,
            greaterThanOrEqualTo(8),
            reason: 'Total frames should be at least 8, but got ${tracer!.measurements['frames_total']}');
        expect((tracer!.measurements['frames_slow'] as SentryMeasurement?)?.value,
            5,
            reason: 'Slow frames measurement should be 5, but got ${tracer!.measurements['frames_slow']}');
        expect(
            (tracer!.measurements['frames_frozen'] as SentryMeasurement?)?.value,
            2,
            reason: 'Frozen frames measurement should be 2, but got ${tracer!.measurements['frames_frozen']}');
        // we don't measure the frames delay or total frames because the timings are not
        // completely accurate in a test env so it may flake
      });
    });
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
}
