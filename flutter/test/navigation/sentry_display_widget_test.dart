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
    when(fixture.mockTimeToDisplayTracker.transactionId).thenReturn(
      fixture.mockSentrySpanContext.spanId,
    );

    SpanId? spanId;

    await tester.pumpWidget(
      MaterialApp(
        home: SentryDisplayWidget(
          child: Builder(
            builder: (context) {
              final currentDisplay = SentryFlutter.currentDisplay();
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
  final MockHub mockHub = MockHub();
  final MockTimeToDisplayTracker mockTimeToDisplayTracker =
      MockTimeToDisplayTracker();
  late SentryNavigatorObserver navigatorObserver;

  Fixture() {
    mockSentrySpanContext = SentrySpanContext(operation: 'ui.load');
    mockSentrySpanContext.spanId = SpanId.newId();

    mockSentryTracer = MockSentryTracer();
    when(mockSentryTracer.context).thenReturn(mockSentrySpanContext);

    when(mockHub.options).thenReturn(options);

    navigatorObserver = SentryNavigatorObserver(
      hub: mockHub,
      autoFinishAfter: const Duration(seconds: 1),
    );
  }
}
