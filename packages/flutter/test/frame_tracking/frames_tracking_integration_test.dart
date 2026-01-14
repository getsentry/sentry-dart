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

    const slowFrame = Duration(milliseconds: 100);
    const frozenFrame = Duration(milliseconds: 800);

    setUp(() async {
      hub = Hub(options);
    });

    Future<void> simulateFrames(
      WidgetTester tester, {
      required List<Duration> frameDurations,
    }) async {
      for (final d in frameDurations) {
        tester.binding.handleBeginFrame(Duration.zero);
        await Future<void>.delayed(d);
        tester.binding.handleDrawFrame();
      }
    }

    Widget buildTestApp({
      required String buttonText,
      required VoidCallback onPressed,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: onPressed,
              child: Text(buttonText),
            ),
          ),
        ),
      );
    }

    testWidgets('with stream lifecycle measures frames',
        (WidgetTester tester) async {
      late SentrySpanV2 parentSpan;
      late SentrySpanV2 childSpan;

      await fromWorkingState(
          options..traceLifecycle = SentryTraceLifecycle.streaming);

      await tester.runAsync(() async {
        final testWidget = buildTestApp(
          buttonText: 'Start Span',
          onPressed: () {
            parentSpan = hub.startSpan('test_parent_span');
            childSpan = hub.startSpan('test_child_span');
          },
        );

        await tester.pumpWidget(testWidget);
        await tester.tap(find.byType(ElevatedButton));

        // Child span: 2 slow + 1 frozen
        await simulateFrames(
          tester,
          frameDurations: const [slowFrame, slowFrame, frozenFrame],
        );
        childSpan.end();

        // Parent span: 3 slow + 1 frozen (parent should also include child's)
        await simulateFrames(
          tester,
          frameDurations: const [slowFrame, slowFrame, slowFrame, frozenFrame],
        );
        parentSpan.end();

        expect(
          childSpan.attributes[SemanticAttributesConstants.framesSlow]?.value,
          2,
        );
        expect(
          childSpan.attributes[SemanticAttributesConstants.framesFrozen]?.value,
          1,
        );

        expect(
          parentSpan.attributes[SemanticAttributesConstants.framesSlow]?.value,
          5,
        );
        expect(
          parentSpan
              .attributes[SemanticAttributesConstants.framesFrozen]?.value,
          2,
        );
        expect(
          parentSpan.attributes[SemanticAttributesConstants.framesTotal]?.value,
          greaterThanOrEqualTo(8),
        );
        // No delay assertions due to test env timing flakiness.
      });
    });

    testWidgets('with static lifecycle measures frames',
        (WidgetTester tester) async {
      SentryTracer? tracer;
      ISentrySpan? child;

      await fromWorkingState(
          options..traceLifecycle = SentryTraceLifecycle.static);

      await tester.runAsync(() async {
        final testWidget = buildTestApp(
          buttonText: 'Start Transaction',
          onPressed: () {
            tracer = hub.startTransaction(
              'test_transaction',
              'test_operation',
              bindToScope: true,
              startTimestamp: options.clock(),
            ) as SentryTracer;

            child = tracer?.startChild(
              'child_operation',
              description: 'Child span',
              startTimestamp: options.clock(),
            );
          },
        );

        await tester.pumpWidget(testWidget);
        await tester.tap(find.byType(ElevatedButton));

        // Child span: 2 slow + 1 frozen
        await simulateFrames(
          tester,
          frameDurations: const [slowFrame, slowFrame, frozenFrame],
        );
        await child?.finish(endTimestamp: options.clock());

        // Tracer: 3 slow + 1 frozen (and will include child's)
        await simulateFrames(
          tester,
          frameDurations: const [slowFrame, slowFrame, slowFrame, frozenFrame],
        );
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
          greaterThanOrEqualTo(8),
        );
        expect(
          (tracer!.measurements['frames_slow'] as SentryMeasurement).value,
          5,
        );
        expect(
          (tracer!.measurements['frames_frozen'] as SentryMeasurement).value,
          2,
        );
        // No delay assertions due to test env timing flakiness.
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
