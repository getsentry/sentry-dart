// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/integrations.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_flutter/src/native/native_frames.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker.dart';
import 'package:sentry_flutter/src/navigation/time_to_initial_display_tracker.dart';

import 'fake_frame_callback_handler.dart';
import 'mocks.dart';
import 'mocks.mocks.dart';

void main() {
  late Fixture fixture;

  PageRoute<dynamic> route(RouteSettings? settings) => PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => Container(),
        settings: settings,
      );

  void _whenAnyStart(MockHub mockHub, ISentrySpan thenReturnSpan) {
    when(mockHub.startTransactionWithContext(
      any,
      bindToScope: anyNamed('bindToScope'),
      waitForChildren: anyNamed('waitForChildren'),
      autoFinishAfter: anyNamed('autoFinishAfter'),
      trimEnd: anyNamed('trimEnd'),
      onFinish: anyNamed('onFinish'),
      customSamplingContext: anyNamed('customSamplingContext'),
      startTimestamp: anyNamed('startTimestamp'),
    )).thenReturn(thenReturnSpan);
    when(mockHub.getSpan()).thenReturn(thenReturnSpan);
  }

  setUp(() {
    fixture = Fixture();
  });

  group('NativeFrames', () {
    late MockSentryNativeBinding mockBinding;

    setUp(() {
      mockBinding = MockSentryNativeBinding();
      SentryFlutter.native = mockBinding;
    });

    tearDown(() {
      SentryFlutter.native = null;
    });

    test('transaction start begins frames collection', () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));
      final mockHub = _MockHub();

      final tracer = getMockSentryTracer();
      _whenAnyStart(mockHub, tracer);
      when(tracer.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      when(tracer.finished).thenReturn(false);
      when(tracer.status).thenReturn(SpanStatus.ok());

      final sut = fixture.getSut(hub: mockHub);

      sut.didPush(currentRoute, null);
      await sut.completedDisplayTracking?.future;

      // Handle internal async method calls.
      await Future.delayed(const Duration(milliseconds: 10), () {});
      verify(mockBinding.beginNativeFrames()).called(1);
    });

    test('transaction finish adds native frames to tracer', () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final options = defaultTestOptions();
      options.tracesSampleRate = 1;
      final hub = Hub(options);

      when(mockBinding.endNativeFrames(any))
          .thenAnswer((_) async => NativeFrames(3, 2, 1));

      final sut = fixture.getSut(hub: hub);

      sut.didPush(currentRoute, null);
      await sut.completedDisplayTracking?.future;

      // Get ref to created transaction
      SentryTracer? actualTransaction;
      hub.configureScope((scope) {
        actualTransaction = scope.span as SentryTracer;
      });

      // Wait for the transaction to finish the async native frame fetching
      await Future<void>.delayed(Duration(milliseconds: 1500));

      verify(mockBinding.beginNativeFrames()).called(1);

      final measurements = actualTransaction?.measurements ?? {};

      expect(measurements.length, 4);

      final expectedTotal = SentryMeasurement.totalFrames(3);
      final expectedSlow = SentryMeasurement.slowFrames(2);
      final expectedFrozen = SentryMeasurement.frozenFrames(1);

      for (final item in measurements.entries) {
        final measurement = item.value;
        if (measurement.name == expectedTotal.name) {
          expect(measurement.value, expectedTotal.value);
        } else if (measurement.name == expectedSlow.name) {
          expect(measurement.value, expectedSlow.value);
        } else if (measurement.name == expectedFrozen.name) {
          expect(measurement.value, expectedFrozen.value);
        }
      }
    });
  });

  group('$SentryNavigatorObserver', () {
    test('didPush starts transaction', () async {
      const name = 'Current Route';
      final currentRoute = route(RouteSettings(name: name));

      const op = 'ui.load';
      final hub = _MockHub();
      final span = getMockSentryTracer(name: name);
      when(span.context).thenReturn(SentrySpanContext(operation: op));
      _whenAnyStart(hub, span);
      when(span.finished).thenReturn(false);
      when(span.status).thenReturn(SpanStatus.ok());
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());

      final sut = fixture.getSut(
        hub: hub,
        autoFinishAfter: Duration(seconds: 5),
      );

      sut.didPush(currentRoute, null);
      await sut.completedDisplayTracking?.future;

      final context = verify(hub.startTransactionWithContext(
        captureAny,
        startTimestamp: anyNamed('startTimestamp'),
        waitForChildren: true,
        autoFinishAfter: anyNamed('autoFinishAfter'),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      )).captured.single as SentryTransactionContext;

      expect(context.name, name);

      hub.configureScope((scope) {
        expect(scope.span?.context.operation, op);
        expect(scope.span, span);
      });
    });

    test('do not bind transaction to scope if no op', () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = _MockHub();

      final span = NoOpSentrySpan();
      _whenAnyStart(hub, span);
      when(hub.getSpan()).thenReturn(null);

      final sut = fixture.getSut(
        hub: hub,
        autoFinishAfter: Duration(seconds: 5),
      );

      sut.didPush(currentRoute, null);
      await sut.completedDisplayTracking?.future;

      verify(hub.startTransactionWithContext(
        any,
        startTimestamp: anyNamed('startTimestamp'),
        waitForChildren: true,
        autoFinishAfter: Duration(seconds: 5),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      ));

      hub.configureScope((scope) {
        expect(scope.span, null);
        expect(scope.transaction, null);
      });
    });

    test('route with empty name does not start transaction', () async {
      final currentRoute = route(null);

      final hub = _MockHub();
      final span = getMockSentryTracer();
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.finished).thenReturn(false);
      when(span.status).thenReturn(SpanStatus.ok());
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(currentRoute, null);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      verifyNever(hub.startTransactionWithContext(
        any,
        startTimestamp: anyNamed('startTimestamp'),
        waitForChildren: true,
        autoFinishAfter: anyNamed('autoFinishAfter'),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      ));

      hub.configureScope((scope) {
        expect(scope.span, null);
      });
    });

    test('no transaction on opt-out', () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = _MockHub();
      final span = getMockSentryTracer();
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      _whenAnyStart(hub, span);
      when(span.finished).thenReturn(false);
      when(span.status).thenReturn(SpanStatus.ok());

      final sut = fixture.getSut(hub: hub, enableAutoTransactions: false);

      sut.didPush(currentRoute, null);

      verifyNever(hub.startTransactionWithContext(
        any,
        startTimestamp: anyNamed('startTimestamp'),
        waitForChildren: true,
        autoFinishAfter: anyNamed('autoFinishAfter'),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      ));

      hub.configureScope((scope) {
        expect(scope.span, null);
      });
    });

    test('do not bind to scope if already set', () {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = _MockHub();
      hub.scope.span = NoOpSentrySpan();

      final span = getMockSentryTracer();
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.finished).thenReturn(false);
      when(span.status).thenReturn(SpanStatus.ok());
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(currentRoute, null);

      verify(hub.startTransactionWithContext(
        any,
        startTimestamp: anyNamed('startTimestamp'),
        waitForChildren: true,
        autoFinishAfter: anyNamed('autoFinishAfter'),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      ));

      hub.configureScope((scope) {
        expect(scope.span, NoOpSentrySpan());
      });
    });

    test('didPush finishes previous transaction', () async {
      final firstRoute = route(RouteSettings(name: 'First Route'));
      final secondRoute = route(RouteSettings(name: 'Second Route'));

      final hub = _MockHub();
      final span = getMockSentryTracer(finished: false) as SentryTracer;
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.status).thenReturn(null);
      when(span.finished).thenReturn(false);
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      when(span.children).thenReturn([]);
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(firstRoute, null);
      sut.didPush(secondRoute, firstRoute);
      sut.didPop(secondRoute, null);

      hub.configureScope((scope) {
        expect(scope.span, null);
      });

      verify(span.finish()).called(2);
    });

    test('didPop finishes transaction', () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = _MockHub();
      final span = getMockSentryTracer(finished: false) as SentryTracer;
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.status).thenReturn(null);
      when(span.finished).thenReturn(false);
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, span);
      when(span.children).thenReturn([]);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(currentRoute, null);
      sut.didPop(currentRoute, null);

      hub.configureScope((scope) {
        expect(scope.span, null);
      });

      verify(span.finish()).called(1);
    });

    test('multiple didPop only finish transaction once', () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = _MockHub();
      final span = getMockSentryTracer(finished: false) as SentryTracer;
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.status).thenReturn(null);
      when(span.children).thenReturn([]);
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(currentRoute, null);
      await sut.completedDisplayTracking?.future;

      sut.didPop(currentRoute, null);
      sut.didPop(currentRoute, null);

      hub.configureScope((scope) {
        expect(scope.span, null);
      });

      verify(span.finish()).called(1);
    });

    test(
        'unfinished children will be finished with deadline_exceeded on didPush',
        () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = _MockHub();
      final span = getMockSentryTracer(finished: false) as SentryTracer;
      final mockChildA = MockSentrySpan();
      final mockChildB = MockSentrySpan();
      when(span.children).thenReturn([
        mockChildB,
        mockChildA,
      ]);
      when(mockChildA.finished).thenReturn(false);
      when(mockChildB.finished).thenReturn(false);
      when(mockChildA.context).thenReturn(SentrySpanContext(
          operation: SentrySpanOperations.uiTimeToInitialDisplay));
      when(mockChildB.context).thenReturn(SentrySpanContext(
          operation: SentrySpanOperations.uiTimeToFullDisplay));
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.status).thenReturn(null);
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      // Push to new screen, e.g app start / root screen
      sut.didPush(currentRoute, null);

      // Push to screen e.g root to user screen
      sut.didPush(currentRoute, null);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      verify(mockChildA.finish(status: SpanStatus.deadlineExceeded()))
          .called(1);
      verify(mockChildB.finish(status: SpanStatus.deadlineExceeded()))
          .called(1);
    });

    test(
        'unfinished children will be finished with deadline_exceeded on didPop',
        () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = _MockHub();
      final span = getMockSentryTracer(finished: false) as SentryTracer;
      final mockChildA = MockSentrySpan();
      final mockChildB = MockSentrySpan();
      when(span.children).thenReturn([
        mockChildB,
        mockChildA,
      ]);
      when(mockChildA.finished).thenReturn(false);
      when(mockChildB.finished).thenReturn(false);
      when(mockChildA.context).thenReturn(SentrySpanContext(
          operation: SentrySpanOperations.uiTimeToInitialDisplay));
      when(mockChildB.context).thenReturn(SentrySpanContext(
          operation: SentrySpanOperations.uiTimeToFullDisplay));
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.status).thenReturn(null);
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      // Push to new screen, e.g root to user screen
      sut.didPush(currentRoute, null);

      // Pop back e.g user to root screen
      sut.didPop(currentRoute, null);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      verify(mockChildA.finish(status: SpanStatus.deadlineExceeded()))
          .called(1);
      verify(mockChildB.finish(status: SpanStatus.deadlineExceeded()))
          .called(1);
    });

    test('route arguments are set on transaction', () async {
      final arguments = {'foo': 'bar'};
      final currentRoute = route(RouteSettings(
        name: 'Current Route',
        arguments: arguments,
      ));

      final hub = _MockHub();
      final span = getMockSentryTracer();
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.status).thenReturn(null);
      when(span.finished).thenReturn(false);
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(currentRoute, null);
      await sut.completedDisplayTracking?.future;

      verify(span.setData('route_settings_arguments', arguments));
    });

    test('flutter root name is replaced', () async {
      final rootRoute = route(RouteSettings(name: '/'));
      NativeAppStartIntegration.setAppStartInfo(
        AppStartInfo(
          AppStartType.cold,
          start: DateTime.now().add(const Duration(seconds: 1)),
          end: DateTime.now().add(const Duration(seconds: 2)),
          pluginRegistration: DateTime.now().add(const Duration(seconds: 3)),
          sentrySetupStart: DateTime.now().add(const Duration(seconds: 4)),
          nativeSpanTimes: [],
        ),
      );

      final hub = _MockHub();
      final span = getMockSentryTracer(name: '/');
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.finished).thenReturn(false);
      when(span.status).thenReturn(SpanStatus.ok());
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(rootRoute, null);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final context = verify(hub.startTransactionWithContext(
        captureAny,
        waitForChildren: true,
        startTimestamp: anyNamed('startTimestamp'),
        autoFinishAfter: anyNamed('autoFinishAfter'),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      )).captured.single as SentryTransactionContext;

      expect(context.name, 'root /');

      hub.configureScope((scope) {
        expect(scope.span, span);
      });
    });

    test('didPush sets current route name', () async {
      const name = 'Current Route';
      final currentRoute = route(RouteSettings(name: name));

      const op = 'navigation';
      final hub = _MockHub();
      final span = getMockSentryTracer(name: name);
      when(span.context).thenReturn(SentrySpanContext(operation: op));
      when(span.finished).thenReturn(false);
      when(span.status).thenReturn(SpanStatus.ok());
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(
        hub: hub,
        autoFinishAfter: Duration(seconds: 5),
      );

      sut.didPush(currentRoute, null);
      await sut.completedDisplayTracking?.future;

      expect(SentryNavigatorObserver.currentRouteName, 'Current Route');
    });

    test('didReplace sets new route name', () {
      const oldRouteName = 'Old Route';
      final oldRoute = route(RouteSettings(name: oldRouteName));
      const newRouteName = 'New Route';
      final newRoute = route(RouteSettings(name: newRouteName));

      const op = 'navigation';
      final hub = _MockHub();
      final span = getMockSentryTracer(name: oldRouteName);
      when(span.context).thenReturn(SentrySpanContext(operation: op));
      when(span.finished).thenReturn(false);
      when(span.status).thenReturn(SpanStatus.ok());
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(
        hub: hub,
        autoFinishAfter: Duration(seconds: 5),
      );

      sut.didPush(oldRoute, null);
      sut.didReplace(newRoute: newRoute, oldRoute: oldRoute);

      expect(SentryNavigatorObserver.currentRouteName, 'New Route');
    });

    test('popRoute sets previous route name', () {
      const oldRouteName = 'Old Route';
      final oldRoute = route(RouteSettings(name: oldRouteName));
      const newRouteName = 'New Route';
      final newRoute = route(RouteSettings(name: newRouteName));

      const op = 'navigation';
      final hub = _MockHub();
      final span = getMockSentryTracer(name: oldRouteName);
      when(span.context).thenReturn(SentrySpanContext(operation: op));
      when(span.status).thenReturn(null);
      when(span.finished).thenReturn(false);
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(
        hub: hub,
        autoFinishAfter: Duration(seconds: 5),
      );

      sut.didPush(oldRoute, null);
      sut.didPop(newRoute, oldRoute);

      expect(SentryNavigatorObserver.currentRouteName, 'Old Route');
    });
  });

  group('RouteObserverBreadcrumb', () {
    test('happy path with string route agrument', () {
      const fromRouteSettings = RouteSettings(
        name: 'from',
        arguments: 'PageTitle',
      );

      const toRouteSettings = RouteSettings(
        name: 'to',
        arguments: 'PageTitle2',
      );

      final breadcrumb = RouteObserverBreadcrumb(
        navigationType: 'didPush',
        from: fromRouteSettings,
        to: toRouteSettings,
        data: {'foo': 'bar'},
      );

      expect(breadcrumb.category, 'navigation');
      expect(breadcrumb.data, <String, dynamic>{
        'state': 'didPush',
        'from': 'from',
        'from_arguments': 'PageTitle',
        'to': 'to',
        'to_arguments': 'PageTitle2',
        'data': {'foo': 'bar'},
      });
    });

    test('happy path with map route agrument', () {
      const fromRouteSettings = RouteSettings(
        name: 'from',
        arguments: 'PageTitle',
      );

      const toRouteSettings = RouteSettings(
        name: 'to',
        arguments: {
          'foo': 123,
          'bar': 'foobar',
        },
      );

      final breadcrumb = RouteObserverBreadcrumb(
        navigationType: 'didPush',
        from: fromRouteSettings,
        to: toRouteSettings,
      );

      expect(breadcrumb.category, 'navigation');
      expect(breadcrumb.data, <String, dynamic>{
        'state': 'didPush',
        'from': 'from',
        'from_arguments': 'PageTitle',
        'to': 'to',
        'to_arguments': {
          'foo': '123',
          'bar': 'foobar',
        },
      });
    });

    test('routes are null', () {
      // both routes are null
      final breadcrumb = RouteObserverBreadcrumb(
        navigationType: 'didPush',
        from: null,
        to: null,
      );

      expect(breadcrumb.category, 'navigation');
      expect(breadcrumb.data, <String, dynamic>{
        'state': 'didPush',
      });
    });

    test('route arguments are null', () {
      const fromRouteSettings = RouteSettings(
        name: 'from',
      );

      const toRouteSettings = RouteSettings(
        name: 'to',
        arguments: null,
      );

      // both routes are null
      final breadcrumb = RouteObserverBreadcrumb(
        navigationType: 'didPush',
        from: fromRouteSettings,
        to: toRouteSettings,
      );

      expect(breadcrumb.category, 'navigation');
      expect(breadcrumb.data, <String, dynamic>{
        'state': 'didPush',
        'from': 'from',
        'to': 'to',
      });
    });

    test('route names are null', () {
      const fromRouteSettings = RouteSettings(name: null, arguments: 'foo');

      const toRouteSettings = RouteSettings(
        name: null,
        arguments: {
          'foo': 123,
        },
      );

      // both routes are null
      final breadcrumb = RouteObserverBreadcrumb(
        navigationType: 'didPush',
        from: fromRouteSettings,
        to: toRouteSettings,
      );

      expect(breadcrumb.category, 'navigation');
      expect(breadcrumb.data, <String, dynamic>{
        'state': 'didPush',
        'from_arguments': 'foo',
        'to_arguments': {
          'foo': '123',
        },
      });
    });
  });

  group('SentryNavigatorObserver', () {
    RouteSettings routeSettings(String? name, [Object? arguments]) =>
        RouteSettings(name: name, arguments: arguments);

    test('Test recording of Breadcrumbs', () {
      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());
      final observer = fixture.getSut(hub: hub);

      final to = routeSettings('to', 'foobar');
      final previous = routeSettings('previous', 'foobar');

      observer.didPush(route(to), route(previous));

      final dynamic breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;
      expect(
        breadcrumb.data,
        RouteObserverBreadcrumb(
          navigationType: 'didPush',
          from: previous,
          to: to,
        ).data,
      );
    });

    test('No arguments', () {
      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());
      final observer = fixture.getSut(hub: hub);

      final to = routeSettings('to');
      final previous = routeSettings('previous');

      observer.didPush(route(to), route(previous));

      final dynamic breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;
      expect(
        breadcrumb.data,
        RouteObserverBreadcrumb(
          navigationType: 'didPush',
          from: previous,
          to: to,
        ).data,
      );
    });

    test('No arguments & no name', () {
      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());
      final observer = fixture.getSut(hub: hub);

      final to = route(null);
      final previous = route(null);

      observer.didReplace(newRoute: to, oldRoute: previous);

      final dynamic breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;
      expect(
        breadcrumb.data,
        RouteObserverBreadcrumb(
          navigationType: 'didReplace',
        ).data,
      );
    });

    test('No RouteSettings', () {
      PageRoute<dynamic> route() => PageRouteBuilder<void>(
            pageBuilder: (_, __, ___) => Container(),
          );

      final hub = _MockHub();
      final observer = fixture.getSut(hub: hub);
      when(hub.getSpan()).thenReturn(NoOpSentrySpan());

      final to = route();
      final previous = route();

      observer.didPop(to, previous);

      final dynamic breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;
      expect(
        breadcrumb.data,
        RouteObserverBreadcrumb(
          navigationType: 'didPop',
        ).data,
      );
    });

    test('route name as transaction', () {
      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());
      final observer = fixture.getSut(
        hub: hub,
        setRouteNameAsTransaction: true,
      );

      final to = routeSettings('to');
      final previous = routeSettings('previous');

      observer.didPush(route(to), route(previous));
      expect(hub.scope.transaction, 'to');

      observer.didPop(route(to), route(previous));
      expect(hub.scope.transaction, 'previous');

      observer.didReplace(newRoute: route(to), oldRoute: route(previous));
      expect(hub.scope.transaction, 'to');
    });

    test('route name does nothing if null', () {
      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());
      final observer = fixture.getSut(
        hub: hub,
        setRouteNameAsTransaction: true,
      );

      hub.scope.transaction = 'foo bar';

      final to = routeSettings(null);
      final previous = routeSettings(null);

      observer.didPush(route(to), route(previous));
      expect(hub.scope.transaction, 'foo bar');
    });

    test('disabled route as transaction', () {
      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());
      final observer =
          fixture.getSut(hub: hub, setRouteNameAsTransaction: false);

      final to = routeSettings('to');
      final previous = routeSettings('previous');

      observer.didPush(route(to), route(previous));
      expect(hub.scope.transaction, null);

      observer.didPop(route(to), route(previous));
      expect(hub.scope.transaction, null);

      observer.didReplace(newRoute: route(to), oldRoute: route(previous));
      expect(hub.scope.transaction, null);
    });

    test('modifying route settings', () {
      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());
      final observer = fixture.getSut(
          hub: hub,
          routeNameExtractor: (settings) {
            if (settings != null && settings.name == 'to') {
              return settings.copyWith(name: 'changed_to');
            }
            return settings;
          });

      final to = routeSettings('to', 'foobar');
      final previous = routeSettings('previous', 'foobar');

      observer.didPush(route(to), route(previous));

      final dynamic breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;
      expect(
        breadcrumb.data,
        RouteObserverBreadcrumb(
          navigationType: 'didPush',
          from: previous,
          to: to.copyWith(name: 'changed_to'),
        ).data,
      );
    });

    test('add additional data', () {
      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());
      final observer = fixture.getSut(
          hub: hub,
          additionalInfoProvider: (from, to) {
            return <String, dynamic>{'foo': 'bar'};
          });

      final to = routeSettings('to', 'foobar');
      final previous = routeSettings('previous', 'foobar');

      observer.didPush(route(to), route(previous));

      final dynamic breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;
      expect(
        breadcrumb.data,
        RouteObserverBreadcrumb(
          navigationType: 'didPush',
          from: previous,
          to: to.copyWith(name: 'to'),
          data: {'foo': 'bar'},
        ).data,
      );
    });

    test('route name as transaction with routeNameExtractor', () {
      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());
      final observer = fixture.getSut(
          hub: hub,
          setRouteNameAsTransaction: true,
          routeNameExtractor: (settings) =>
              settings?.copyWith(name: '${settings.name}_test'));

      final to = routeSettings('to');
      final previous = routeSettings('previous');

      observer.didPush(route(to), route(previous));
      expect(hub.scope.transaction, 'to_test');

      observer.didPop(route(to), route(previous));
      expect(hub.scope.transaction, 'previous_test');

      observer.didReplace(newRoute: route(to), oldRoute: route(previous));
      expect(hub.scope.transaction, 'to_test');
    });
  });
}

class Fixture {
  SentryNavigatorObserver getSut({
    required Hub hub,
    bool enableAutoTransactions = true,
    Duration autoFinishAfter = const Duration(seconds: 1),
    bool setRouteNameAsTransaction = false,
    RouteNameExtractor? routeNameExtractor,
    AdditionalInfoExtractor? additionalInfoProvider,
    bool enableTimeToFullDisplayTracing = false,
  }) {
    final frameCallbackHandler = FakeFrameCallbackHandler();
    final timeToInitialDisplayTracker =
        TimeToInitialDisplayTracker(frameCallbackHandler: frameCallbackHandler);
    final timeToDisplayTracker = TimeToDisplayTracker(
      ttidTracker: timeToInitialDisplayTracker,
      enableTimeToFullDisplayTracing: enableTimeToFullDisplayTracing,
    );
    return SentryNavigatorObserver(
      hub: hub,
      enableAutoTransactions: enableAutoTransactions,
      autoFinishAfter: autoFinishAfter,
      setRouteNameAsTransaction: setRouteNameAsTransaction,
      routeNameExtractor: routeNameExtractor,
      additionalInfoProvider: additionalInfoProvider,
      timeToDisplayTracker: timeToDisplayTracker,
    );
  }

  SentrySpanContext mockContext() {
    return SentrySpanContext(operation: 'op');
  }
}

class _MockHub extends MockHub {
  @override
  final options = defaultTestOptions();

  @override
  late final scope = Scope(options);

  @override
  FutureOr<void> configureScope(ScopeCallback? callback) async {
    await callback?.call(scope);
  }
}

ISentrySpan getMockSentryTracer({String? name, bool? finished}) {
  final tracer = MockSentryTracer();
  when(tracer.name).thenReturn(name ?? 'name');
  when(tracer.finished).thenReturn(finished ?? true);
  return tracer;
}

extension RouteSettingsExtensions on RouteSettings {
  /// Creates a copy of this route settings object with the given fields
  /// replaced with the new values.
  /// Flutter 3.6 beta removed copyWith but we use it for testing
  RouteSettings copyWith({
    String? name,
    Object? arguments,
  }) {
    return RouteSettings(
      name: name ?? this.name,
      arguments: arguments ?? this.arguments,
    );
  }
}
