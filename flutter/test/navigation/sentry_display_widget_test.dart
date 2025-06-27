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
    await tester.pumpWidget(
      MaterialApp(
        home: SentryDisplayWidget(
          hub: fixture.mockHub,
          child: TestStatefulWidget(),
        ),
      ),
    );

    // Wait for the frame to be rendered
    await tester.pumpAndSettle();

    verify(fixture.mockTimeToDisplayTracker.reportFullyDisplayed(
      spanId: fixture.mockSentrySpanContext.spanId,
    )).called(1);
  });

  testWidgets(
      '$SentryDisplayWidget reports calls ttfd immediately if child is a StatelessWidget',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SentryDisplayWidget(
          hub: fixture.mockHub,
          child: TestStatelessWidget(),
        ),
      ),
    );

    // Wait for the frame to be rendered
    await tester.pumpAndSettle();

    verify(fixture.mockTimeToDisplayTracker.reportFullyDisplayed(
      spanId: fixture.mockSentrySpanContext.spanId,
    )).called(1);
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

class TestStatelessWidget extends StatelessWidget {
  const TestStatelessWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('Test');
  }
}

class TestStatefulWidget extends StatefulWidget {
  const TestStatefulWidget({super.key});

  @override
  State<TestStatefulWidget> createState() => _TestStatefulWidgetState();
}

class _TestStatefulWidgetState extends State<TestStatefulWidget> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(microseconds: 1), () {
      // Some long running task
      if (mounted) {
        SentryDisplayWidget.of(context).reportFullyDisplayed();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Text('Test');
  }
}
