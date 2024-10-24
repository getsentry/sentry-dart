// ignore_for_file: invalid_use_of_internal_member
@TestOn('vm')
library flutter_test;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/frame_tracking/sentry_frame_tracking_binding_mixin.dart';
import 'package:sentry_flutter/src/integrations/frame_tracker_integration.dart';

import '../binding.dart';
import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  SentryAutomatedTestWidgetsFlutterBinding.ensureInitialized();

  late Hub hub;
  final options = defaultTestOptions();

  setUp(() async {
    options.tracesSampleRate = 1.0;
    hub = Hub(options);

    final mockNativeBinding = MockSentryNativeBinding();
    when(mockNativeBinding.displayRefreshRate()).thenAnswer((_) async => 60);
    await FrameTrackingIntegration(mockNativeBinding,
            isCompatibleBinding: (binding) =>
                binding is SentryAutomatedTestWidgetsFlutterBinding)
        .call(hub, options);

    expect(SentryFrameTrackingBindingMixin.frameTracker, isNotNull);
  });

  testWidgets('Frame tracking measures frames', (WidgetTester tester) async {
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
      expect(childSpan.data['frames.slow'] as int, 2);
      expect(childSpan.data['frames.frozen'] as int, 1);

      // Verify tracer
      expect(tracer!.data['frames.slow'] as int, 5);
      expect(tracer!.data['frames.frozen'] as int, 2);
      expect(
          (tracer!.measurements['frames_total'] as SentryMeasurement).value, 9);
      expect(
          (tracer!.measurements['frames_slow'] as SentryMeasurement).value, 5);
      expect((tracer!.measurements['frames_frozen'] as SentryMeasurement).value,
          2);
      // we don't measure the frames delay or total frames because the timings are not
      // completely accurate in a test env so it may flake
    });
  });
}
