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

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  // default bindings is used instead of SentryWidgetsFlutterBinding
  // this should lead to no frame tracker being created

  late Hub hub;
  final options = defaultTestOptions();

  setUp(() async {
    options.tracesSampleRate = 1.0;
    hub = Hub(options);

    final mockNativeBinding = MockSentryNativeBinding();
    when(mockNativeBinding.displayRefreshRate()).thenAnswer((_) async => 60);
    await FrameTrackingIntegration(mockNativeBinding).call(hub, options);
  });

  testWidgets('Frame tracking does not measure frames',
      (WidgetTester tester) async {
    SentryTracer? tracer;

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
                tracer?.startChild('child_operation',
                    description: 'Child span', startTimestamp: options.clock());
              },
            ),
          ),
        ),
      );

      await tester.pumpWidget(testWidget);

      await tester.tap(find.byType(ElevatedButton));

      await tracer?.finish(endTimestamp: options.clock());
      expect(tracer, isNotNull);

      // Frame tracker should be null if we don't use the SentryWidgetsFlutterBinding
      expect(SentryFrameTrackingBindingMixin.frameTracker, isNull);

      // Verify child span
      final childSpan = tracer!.children.first;
      expect(childSpan.data, isEmpty);

      // Verify tracer
      expect(tracer!.data, isEmpty);
      expect(tracer!.measurements, isEmpty);
    });
  });
}
