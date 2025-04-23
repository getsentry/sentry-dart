import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

void main() {
  late Fixture fixture;

  PageRoute<dynamic> route(RouteSettings? settings) => PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => Container(),
        settings: settings,
      );

  setUp(() async {
    fixture = Fixture();
    await SentryFlutter.init(
      (options) async {
        options.dsn = fakeDsn;
        options.timeToDisplayTracker = fixture.mockTimeToDisplayTracker;
      },
    );
  });

  tearDown(() async {
    await Sentry.close();
  });

  testWidgets(
      '$SentryDisplayWidget reports display with current route spanId when child calls reportFullDisplay',
      (WidgetTester tester) async {
    const testRouteName = 'test-route';
    final testRoute = route(RouteSettings(name: testRouteName));
    fixture.navigatorObserver.didPush(testRoute, null);

    SpanId? spanId;

    await tester.pumpWidget(
      MaterialApp(
        home: SentryDisplayWidget(
          child: Builder(
            builder: (context) {
              final currentDisplay = SentryNavigatorObserver.currentDisplay;
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

    verify(fixture.mockTimeToDisplayTracker
            .reportFullyDisplayed(spanId: spanId))
        .called(1);
  });
}

class Fixture {
  final options = defaultTestOptions();

  late SentrySpanContext mockSentrySpanContext;
  late MockSentryTracer mockSentryTracer;
  late MockHub mockHub;
  late MockTimeToDisplayTracker mockTimeToDisplayTracker;
  late SentryNavigatorObserver navigatorObserver;

  Fixture() {
    mockSentrySpanContext = SentrySpanContext(operation: 'ui.load');
    mockSentrySpanContext.spanId = SpanId.newId();

    mockSentryTracer = MockSentryTracer();
    when(mockSentryTracer.context).thenReturn(mockSentrySpanContext);
    when(mockSentryTracer.name).thenReturn('foo');
    when(mockSentryTracer.startTimestamp).thenReturn(DateTime.now());
    when(mockSentryTracer.startChild(any,
            description: anyNamed('description'),
            startTimestamp: anyNamed('startTimestamp')))
        .thenAnswer((_) => NoOpSentrySpan());
    when(mockSentryTracer.setMeasurement(any, any, unit: anyNamed('unit')))
        .thenAnswer((_) => Future<void>.value());
    when(mockSentryTracer.finish(endTimestamp: anyNamed('endTimestamp')))
        .thenAnswer((_) => Future<void>.value());

    mockHub = MockHub();
    when(mockHub.options).thenReturn(options);
    when(mockHub.configureScope(any)).thenAnswer((_) => Future<void>.value());
    when(mockHub.startTransactionWithContext(
      any,
      customSamplingContext: anyNamed('customSamplingContext'),
      startTimestamp: anyNamed('startTimestamp'),
      bindToScope: anyNamed('bindToScope'),
      waitForChildren: anyNamed('waitForChildren'),
      autoFinishAfter: anyNamed('autoFinishAfter'),
      trimEnd: anyNamed('trimEnd'),
      onFinish: anyNamed('onFinish'),
    )).thenAnswer((_) => mockSentryTracer);

    mockTimeToDisplayTracker = MockTimeToDisplayTracker();
    when(mockTimeToDisplayTracker.reportFullyDisplayed(
            spanId: anyNamed('spanId')))
        .thenAnswer((_) => Future<void>.value());

    navigatorObserver = SentryNavigatorObserver(
      hub: mockHub,
      autoFinishAfter: const Duration(seconds: 1),
    );
  }
}
