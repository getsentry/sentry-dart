// ignore_for_file: invalid_use_of_internal_member
@TestOn('vm')
library flutter_test;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/frame_tracking/sentry_frame_tracking_binding_mixin.dart';
import 'package:sentry_flutter/src/frame_tracking/span_frame_metrics_calculator.dart';
import 'package:sentry_flutter/src/frame_tracking/span_frame_metrics_collector.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  // default bindings is used automatically

  late Hub hub;
  late MockSentryNativeBinding mockNativeBinding;
  final options = defaultTestOptions();

  setUp(() {
    options.tracesSampleRate = 1.0;

    mockNativeBinding = MockSentryNativeBinding();
    when(mockNativeBinding.displayRefreshRate()).thenAnswer((_) async => 60);
    final spanFrameMetricsCalculator = SpanFrameMetricsCalculator();
    SentryFrameTrackingBindingMixin.initializeFrameTracker(options);
    final tracker = SentryFrameTrackingBindingMixin.frameTracker;
    final spanFrameMetricsCollector = SpanFrameMetricsCollector(
        options, tracker!, spanFrameMetricsCalculator, mockNativeBinding);

    options.performanceCollectors.add(spanFrameMetricsCollector);

    hub = Hub(options);
  });

  testWidgets('Frame tracking does not measure frames',
      (WidgetTester tester) async {
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
                    description: 'Child span', startTimestamp: options.clock());
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
      expect(childSpan.data, isEmpty);

      // Verify tracer
      expect(tracer!.data, isEmpty);
      expect(tracer!.measurements, isEmpty);
      // we don't measure the frames delay or total frames because the timings are not
      // completely accurate in a test env so it may flake
    });
  });
}
