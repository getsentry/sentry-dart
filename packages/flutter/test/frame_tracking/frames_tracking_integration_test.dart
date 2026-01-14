// ignore_for_file: invalid_use_of_internal_member
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
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
    });

    testWidgets('with stream lifecycle measures frames',
        (WidgetTester tester) async {
      late SentrySpanV2 parentSpan;
      late SentrySpanV2 childSpan;

      await fromWorkingState(
          options..traceLifecycle = SentryTraceLifecycle.streaming);

      await tester.runAsync(() async {
        Widget testWidget = MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                child: Text('Start Span'),
                onPressed: () {
                  parentSpan = hub.startSpan('test_parent_span');
                  childSpan = hub.startSpan('test_child_span');
                },
              ),
            ),
          ),
        );

        await tester.pumpWidget(testWidget);

        await tester.tap(find.byType(ElevatedButton));

        /// Generates 2 slow and 1 frozen frame for the child span
        Future<void> _simulateChildSpanFrames() async {
          tester.binding.handleBeginFrame(Duration());
          await Future<void>.delayed(Duration(milliseconds: 100));
          tester.binding.handleDrawFrame();

          tester.binding.handleBeginFrame(Duration());
          await Future<void>.delayed(Duration(milliseconds: 100));
          tester.binding.handleDrawFrame();

          tester.binding.handleBeginFrame(Duration());
          await Future<void>.delayed(Duration(milliseconds: 800));
          tester.binding.handleDrawFrame();
        }

        await _simulateChildSpanFrames();
        childSpan.end();

        /// Generates 3 slow and 1 frozen frame for the tracer
        Future<void> _simulateTracerFrames() async {
          tester.binding.handleBeginFrame(Duration());
          await Future<void>.delayed(Duration(milliseconds: 100));
          tester.binding.handleDrawFrame();

          tester.binding.handleBeginFrame(Duration());
          await Future<void>.delayed(Duration(milliseconds: 100));
          tester.binding.handleDrawFrame();

          tester.binding.handleBeginFrame(Duration());
          await Future<void>.delayed(Duration(milliseconds: 100));
          tester.binding.handleDrawFrame();

          tester.binding.handleBeginFrame(Duration());
          await Future<void>.delayed(Duration(milliseconds: 800));
          tester.binding.handleDrawFrame();
        }

        await _simulateTracerFrames();
        parentSpan.end();

        expect(
            childSpan.attributes[SemanticAttributesConstants.framesSlow]?.value,
            2);
        expect(
            childSpan
                .attributes[SemanticAttributesConstants.framesFrozen]?.value,
            1);

        expect(
            parentSpan
                .attributes[SemanticAttributesConstants.framesSlow]?.value,
            5);
        expect(
            parentSpan
                .attributes[SemanticAttributesConstants.framesFrozen]?.value,
            2);
        expect(
            parentSpan
                .attributes[SemanticAttributesConstants.framesTotal]?.value,
            greaterThanOrEqualTo(8));
        expect(
            parentSpan
                .attributes[SemanticAttributesConstants.framesSlow]?.value,
            5);
        expect(
            parentSpan
                .attributes[SemanticAttributesConstants.framesFrozen]?.value,
            2);
        // we don't measure the frames delay or total frames because the timings are not
        // completely accurate in a test env so it may flake
      });
    });

    testWidgets('with static lifecycle measures frames',
        (WidgetTester tester) async {
      SentryTracer? tracer;
      ISentrySpan? child;

      await fromWorkingState(
          options..traceLifecycle = SentryTraceLifecycle.static);

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

        /// Generates 2 slow and 1 frozen frame for the child span
        Future<void> _simulateChildSpanFrames() async {
          tester.binding.handleBeginFrame(Duration());
          await Future<void>.delayed(Duration(milliseconds: 100));
          tester.binding.handleDrawFrame();

          tester.binding.handleBeginFrame(Duration());
          await Future<void>.delayed(Duration(milliseconds: 100));
          tester.binding.handleDrawFrame();

          tester.binding.handleBeginFrame(Duration());
          await Future<void>.delayed(Duration(milliseconds: 800));
          tester.binding.handleDrawFrame();
        }

        await _simulateChildSpanFrames();
        await child?.finish(endTimestamp: options.clock());

        /// Generates 3 slow and 1 frozen frame for the tracer
        /// However when asserting later, the tracer will also include the number
        /// of slow and frozen frames from the child span.
        Future<void> _simulateTracerFrames() async {
          tester.binding.handleBeginFrame(Duration());
          await Future<void>.delayed(Duration(milliseconds: 100));
          tester.binding.handleDrawFrame();

          tester.binding.handleBeginFrame(Duration());
          await Future<void>.delayed(Duration(milliseconds: 100));
          tester.binding.handleDrawFrame();

          tester.binding.handleBeginFrame(Duration());
          await Future<void>.delayed(Duration(milliseconds: 100));
          tester.binding.handleDrawFrame();

          tester.binding.handleBeginFrame(Duration());
          await Future<void>.delayed(Duration(milliseconds: 800));
          tester.binding.handleDrawFrame();
        }

        await _simulateTracerFrames();
        await tracer?.finish(endTimestamp: options.clock());

        expect(tracer, isNotNull);

        // Verify child span
        final childSpan = tracer!.children.first;
        expect(childSpan.data['frames.slow'] as int, 2);
        expect(childSpan.data['frames.frozen'] as int, 1);

        // Verify tracer
        expect(tracer!.data['frames.slow'] as int, 5);
        expect(tracer!.data['frames.frozen'] as int, 2);
        expect(
            (tracer!.measurements['frames_total'] as SentryMeasurement).value,
            greaterThanOrEqualTo(8));
        expect((tracer!.measurements['frames_slow'] as SentryMeasurement).value,
            5);
        expect(
            (tracer!.measurements['frames_frozen'] as SentryMeasurement).value,
            2);
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

  group('with streaming lifecycle', () {
    setUp(() {
      options.traceLifecycle = SentryTraceLifecycle.streaming;
    });

    test('registers lifecycle callbacks', () async {
      await fromWorkingState(options);

      expect(
        options.lifecycleRegistry.lifecycleCallbacks.containsKey(OnSpanStartV2),
        isTrue,
      );
      expect(
        options.lifecycleRegistry.lifecycleCallbacks.containsKey(OnSpanEndV2),
        isTrue,
      );
    });

    test('does not add collector to performance collectors', () async {
      await fromWorkingState(options);

      expect(options.performanceCollectors, isEmpty);
    });
  });
}
