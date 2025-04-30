import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

void main() {
  late Fixture fixture;

  setUp(() async {
    fixture = Fixture();
  });

  testWidgets(
      '$SentryDisplayWidget reports display with current route spanId when child calls reportFullDisplay',
      (WidgetTester tester) async {
    SpanId? spanId;

    await tester.pumpWidget(
      MaterialApp(
        home: SentryDisplayWidget(
          hub: fixture.mockHub,
          child: Builder(
            builder: (context) {
              final currentDisplay =
                  SentryFlutter.currentDisplay(hub: fixture.mockHub);
              spanId = currentDisplay?.spanId;

              expect(spanId, isNotNull);
              expect(spanId, fixture.mockSentrySpanContext.spanId);

              SentryDisplayWidget.of(context).reportFullyDisplayed();
              return const Text('Test');
            },
          ),
        ),
      ),
    );

    // Wait for the frame to be rendered
    await tester.pumpAndSettle();

    verify(fixture.mockTimeToDisplayTracker
            .reportFullyDisplayed(spanId: spanId))
        .called(1);
  });
}

class Fixture {
  final options = defaultTestOptions()..tracesSampleRate = 1.0;

  late SentrySpanContext mockSentrySpanContext;
  late MockSentryTracer mockSentryTracer;
  final MockHub mockHub = MockHub();
  final MockTimeToDisplayTracker mockTimeToDisplayTracker =
      MockTimeToDisplayTracker();

  Fixture() {
    mockSentrySpanContext = SentrySpanContext(operation: 'ui.load');
    mockSentrySpanContext.spanId = SpanId.newId();

    options.timeToDisplayTracker = mockTimeToDisplayTracker;

    when(mockTimeToDisplayTracker.transactionId).thenReturn(
      mockSentrySpanContext.spanId,
    );

    mockSentryTracer = MockSentryTracer();
    when(mockSentryTracer.context).thenReturn(mockSentrySpanContext);

    when(mockHub.options).thenReturn(options);

    options.timeToDisplayTracker = mockTimeToDisplayTracker;
  }
}
