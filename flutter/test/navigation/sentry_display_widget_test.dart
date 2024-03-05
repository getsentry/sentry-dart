// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_flutter/src/integrations/integrations.dart';
import 'package:sentry_flutter/src/navigation/sentry_display_widget.dart';
import 'package:sentry_flutter/src/navigation/time_to_initial_display_tracker.dart';

import '../fake_frame_callback_handler.dart';
import '../mocks.dart';

void main() {
  PageRoute<dynamic> route(RouteSettings? settings) => PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => Container(),
        settings: settings,
      );

  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  testWidgets('SentryDisplayWidget reports manual ttid span after didPush',
      (WidgetTester tester) async {
    final currentRoute = route(RouteSettings(name: 'Current Route'));

    await tester.runAsync(() async {
      fixture.navigatorObserver.didPush(currentRoute, null);
      await tester.pumpWidget(fixture.getSut());
      await fixture.navigatorObserver.completedDisplayTracking?.future;
    });

    final tracer = fixture.hub.getSpan() as SentryTracer;
    final spans = tracer.children.where((element) =>
        element.context.operation ==
        SentrySpanOperations.uiTimeToInitialDisplay);

    expect(spans, hasLength(1));
    final ttidSpan = spans.first;
    expect(ttidSpan.context.operation,
        SentrySpanOperations.uiTimeToInitialDisplay);
    expect(ttidSpan.finished, isTrue);
    expect(ttidSpan.context.description, 'Current Route initial display');
    expect(ttidSpan.origin, SentryTraceOrigins.manualUiTimeToDisplay);
    expect(tracer.measurements, hasLength(1));
    final measurement = tracer.measurements['time_to_initial_display'];
    expect(measurement, isNotNull);
    expect(measurement?.unit, DurationSentryMeasurementUnit.milliSecond);
  });

  testWidgets('SentryDisplayWidget is ignored for app starts',
      (WidgetTester tester) async {
    final currentRoute = route(RouteSettings(name: '/'));
    final appStartInfo = AppStartInfo(
      AppStartType.cold,
      start: DateTime.now().add(Duration(seconds: 1)),
      end: DateTime.now().add(Duration(seconds: 2)),
    );
    NativeAppStartIntegration.setAppStartInfo(appStartInfo);

    await tester.runAsync(() async {
      fixture.navigatorObserver.didPush(currentRoute, null);
      await tester.pumpWidget(fixture.getSut());
      await fixture.navigatorObserver.completedDisplayTracking?.future;
    });

    final tracer = fixture.hub.getSpan() as SentryTracer;
    final spans = tracer.children.where((element) =>
        element.context.operation ==
        SentrySpanOperations.uiTimeToInitialDisplay);

    expect(spans, hasLength(1));

    final ttidSpan = spans.first;
    expect(ttidSpan.context.operation,
        SentrySpanOperations.uiTimeToInitialDisplay);
    expect(ttidSpan.finished, isTrue);
    expect(ttidSpan.context.description, 'root ("/") initial display');
    expect(ttidSpan.origin, SentryTraceOrigins.autoUiTimeToDisplay);

    expect(ttidSpan.startTimestamp.toUtc(), appStartInfo.start.toUtc());
    expect(
        ttidSpan.endTimestamp?.toUtc(), appStartInfo.end.toUtc());

    expect(tracer.measurements, hasLength(1));
    final measurement = tracer.measurements['time_to_initial_display'];
    expect(measurement, isNotNull);
    expect(measurement?.value, 1000);
    expect(measurement?.unit, DurationSentryMeasurementUnit.milliSecond);
  });
}

class Fixture {
  final Hub hub =
      Hub(SentryFlutterOptions(dsn: fakeDsn)..tracesSampleRate = 1.0);
  late final SentryNavigatorObserver navigatorObserver;
  final fakeFrameCallbackHandler = FakeFrameCallbackHandler();

  Fixture() {
    SentryFlutter.native = TestMockSentryNative();
    navigatorObserver = SentryNavigatorObserver(hub: hub);
  }

  MaterialApp getSut() {
    return MaterialApp(
      home: SentryDisplayWidget(
        frameCallbackHandler: FakeFrameCallbackHandler(
          finishAfterDuration: Duration(milliseconds: 50),
        ),
        child: Text('my text'),
      ),
    );
  }
}
