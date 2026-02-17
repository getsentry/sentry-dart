// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/web_session_integration.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

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

  group('$SentryNavigatorObserver', () {
    test('didPush on root does not start a transaction', () async {
      const name = '/';
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

      verifyNever(hub.startTransactionWithContext(
        any,
        startTimestamp: anyNamed('startTimestamp'),
        waitForChildren: anyNamed('waitForChildren'),
        autoFinishAfter: anyNamed('autoFinishAfter'),
        trimEnd: anyNamed('trimEnd'),
        onFinish: anyNamed('onFinish'),
      ));
    });

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

      final context = verify(hub.startTransactionWithContext(
        captureAny,
        startTimestamp: anyNamed('startTimestamp'),
        waitForChildren: true,
        autoFinishAfter: anyNamed('autoFinishAfter'),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      )).captured.single as SentryTransactionContext;

      expect(context.name, name);

      await hub.configureScope((scope) {
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

      verify(hub.startTransactionWithContext(
        any,
        startTimestamp: anyNamed('startTimestamp'),
        waitForChildren: true,
        autoFinishAfter: Duration(seconds: 5),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      ));

      await hub.configureScope((scope) {
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

      await hub.configureScope((scope) {
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

      await hub.configureScope((scope) {
        expect(scope.span, null);
      });
    });

    test('do not bind to scope if already set', () async {
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

      await hub.configureScope((scope) {
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

      await hub.configureScope((scope) {
        expect(scope.span, null);
      });

      verify(fixture.mockTimeToDisplayTracker.cancelUnfinishedSpans(
        span,
        any,
      )).called(2);

      verify(
        span.finish(endTimestamp: captureAnyNamed('endTimestamp')),
      ).called(2);
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

      await hub.configureScope((scope) {
        expect(scope.span, null);
      });

      verify(fixture.mockTimeToDisplayTracker.cancelUnfinishedSpans(
        span,
        any,
      )).called(1);

      verify(
        span.finish(endTimestamp: captureAnyNamed('endTimestamp')),
      ).called(1);
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

      sut.didPop(currentRoute, null);
      sut.didPop(currentRoute, null);

      await hub.configureScope((scope) {
        expect(scope.span, null);
      });

      verify(fixture.mockTimeToDisplayTracker.cancelUnfinishedSpans(
        span,
        any,
      )).called(1);

      verify(
        span.finish(endTimestamp: captureAnyNamed('endTimestamp')),
      ).called(1);
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

      verify(span.setData('route_settings_arguments', arguments));
    });

    test('didPush sets current route name', () async {
      const name = 'Current Route';
      final currentRoute = route(RouteSettings(name: name));

      const op = 'navigation';
      final hub = _MockHub();

      final spanContext =
          SentrySpanContext(operation: op, spanId: SpanId.newId());
      final span = getMockSentryTracer(name: name);
      when(span.context).thenReturn(spanContext);
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
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(SentryNavigatorObserver.currentRouteName, 'Current Route');
    });

    test('didReplace sets new route name', () {
      const oldRouteName = 'Old Route';
      final oldRoute = route(RouteSettings(name: oldRouteName));
      const newRouteName = 'New Route';
      final newRoute = route(RouteSettings(name: newRouteName));

      const op = 'navigation';
      final hub = _MockHub();
      final spanContext =
          SentrySpanContext(operation: op, spanId: SpanId.newId());
      final span = getMockSentryTracer(name: oldRouteName);
      when(span.context).thenReturn(spanContext);
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
      when(span.children).thenReturn([]);
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

    group('root route transaction behavior by platform', () {
      // Platforms that skip root transactions in the observer (have app start integration)
      final platforms = [
        ('iOS', MockPlatform.iOS()),
        ('Android', MockPlatform.android()),
        ('macOS', MockPlatform.macOS(isWeb: false)),
        ('Web', MockPlatform(isWeb: true)),
        ('Linux', MockPlatform.linux(isWeb: false)),
        ('Windows', MockPlatform.windows(isWeb: false)),
      ];

      void testRootRouteTransaction({
        required String platformName,
        required MockPlatform platform,
      }) {
        test('root route does not start transaction on $platformName',
            () async {
          final rootRoute = route(RouteSettings(name: '/'));

          final hub = _MockHub();
          hub.options.platform = platform;
          final span = getMockSentryTracer();
          when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
          when(span.finished).thenReturn(false);
          when(span.status).thenReturn(SpanStatus.ok());
          _whenAnyStart(hub, span);

          final sut = fixture.getSut(hub: hub);

          sut.didPush(rootRoute, null);
          await Future<void>.delayed(const Duration(milliseconds: 100));

          verifyNever(hub.startTransactionWithContext(
            any,
            startTimestamp: anyNamed('startTimestamp'),
            waitForChildren: true,
            autoFinishAfter: anyNamed('autoFinishAfter'),
            trimEnd: true,
            onFinish: anyNamed('onFinish'),
          ));

          await hub.configureScope((scope) {
            expect(scope.span, null);
          });
        });
      }

      for (final (platformName, platform) in platforms) {
        testRootRouteTransaction(
          platformName: platformName,
          platform: platform,
        );
      }
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

    test('ignores Route and prevents recognition of this route for didPush',
        () async {
      final firstRoute = route(RouteSettings(name: 'default'));
      final secondRoute = route(RouteSettings(name: 'testRoute'));

      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());

      final sut = fixture.getSut(hub: hub, ignoreRoutes: ["testRoute"]);

      sut.didPush(firstRoute, null);
      expect(
          SentryNavigatorObserver.currentRouteName, firstRoute.settings.name);
      sut.didPush(secondRoute, firstRoute);
      expect(
          SentryNavigatorObserver.currentRouteName, firstRoute.settings.name);
      sut.didPush(firstRoute, secondRoute);
      expect(
          SentryNavigatorObserver.currentRouteName, firstRoute.settings.name);
    });

    test('ignores Route and prevents recognition of this route for didPop',
        () async {
      final firstRoute = route(RouteSettings(name: 'default'));
      final secondRoute = route(RouteSettings(name: 'testRoute'));

      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());

      final sut = fixture.getSut(hub: hub, ignoreRoutes: ["testRoute"]);

      sut.didPush(firstRoute, null);
      expect(
          SentryNavigatorObserver.currentRouteName, firstRoute.settings.name);
      sut.didPush(secondRoute, firstRoute);
      expect(
          SentryNavigatorObserver.currentRouteName, firstRoute.settings.name);
      sut.didPop(firstRoute, secondRoute);
      expect(
          SentryNavigatorObserver.currentRouteName, firstRoute.settings.name);
    });

    test('ignores Route and prevents recognition of this route for didReplace',
        () async {
      final firstRoute = route(RouteSettings(name: 'default'));
      final secondRoute = route(RouteSettings(name: 'testRoute'));

      final hub = _MockHub();

      final sut = fixture.getSut(hub: hub, ignoreRoutes: ["testRoute"]);

      sut.didReplace(newRoute: firstRoute);
      expect(
          SentryNavigatorObserver.currentRouteName, firstRoute.settings.name);
      sut.didReplace(newRoute: secondRoute, oldRoute: firstRoute);
      expect(
          SentryNavigatorObserver.currentRouteName, firstRoute.settings.name);
      sut.didReplace(newRoute: firstRoute, oldRoute: secondRoute);
      expect(
          SentryNavigatorObserver.currentRouteName, firstRoute.settings.name);
    });
  });

  group('web sessions', () {
    late MockSentryNativeBinding mockNative;
    late MockHub mockHub;

    setUp(() {
      mockHub = _MockHub();
      mockNative = MockSentryNativeBinding();
      SentryFlutter.native = mockNative;

      when(mockNative.startSession(ignoreDuration: true)).thenAnswer((_) {});
      when(mockNative.captureSession()).thenAnswer((_) {});
    });

    tearDown(() {
      SentryFlutter.native = null;
    });

    void _setupWebSessionIntegration() {
      final integration = WebSessionIntegration(mockNative);
      mockHub.options.addIntegration(integration);
      integration.call(mockHub, mockHub.options as SentryFlutterOptions);
    }

    SentryNavigatorObserver _getSut() {
      return fixture.getSut(hub: mockHub, enableAutoTransactions: false);
    }

    group('$WebSessionIntegration initialization', () {
      test('webSessionHandler remains null if integration does not exist', () {
        final sut = _getSut();

        expect(sut.webSessionHandler, isNull);
      });

      test(
          'webSessionHandler remains null if integration exists but not called before initialization',
          () {
        final integration = WebSessionIntegration(mockNative);
        mockHub.options.addIntegration(integration);
        // integration.call() is not executed

        final sut = _getSut();
        expect(sut.webSessionHandler, isNull);
      });
    });

    group('on platform web', () {
      setUp(() {
        mockHub.options.platform = MockPlatform(isWeb: true);
      });

      test('init enables sets webSessionHandler when properly set up', () {
        _setupWebSessionIntegration();
        final sut = _getSut();

        expect(sut.webSessionHandler, isNotNull);
      });

      group('session handling', () {
        setUp(() {
          _setupWebSessionIntegration();
        });

        test('starts new session on didPush between different routes',
            () async {
          final fromRoute = route(RouteSettings(name: 'From Route'));
          final toRoute = route(RouteSettings(name: 'To Route'));

          final sut = _getSut();

          sut.didPush(toRoute, fromRoute);
          // Delay a bit since we use await with the session api and we cannot await the navigation methods
          await Future<void>.delayed(Duration(milliseconds: 100));

          verify(mockNative.startSession(ignoreDuration: true)).called(1);
          verify(mockNative.captureSession()).called(1);
        });

        test('starts new session on didPop between different routes', () async {
          final fromRoute = route(RouteSettings(name: 'From Route'));
          final toRoute = route(RouteSettings(name: 'To Route'));

          final sut = _getSut();

          sut.didPop(toRoute, fromRoute);
          // Delay a bit since we use await with the session api and we cannot await the navigation methods
          await Future<void>.delayed(Duration(milliseconds: 100));

          verify(mockNative.startSession(ignoreDuration: true)).called(1);
          verify(mockNative.captureSession()).called(1);
        });

        test('starts new session on didReplace between different routes',
            () async {
          final fromRoute = route(RouteSettings(name: 'From Route'));
          final toRoute = route(RouteSettings(name: 'To Route'));

          final sut = _getSut();

          sut.didReplace(newRoute: toRoute, oldRoute: fromRoute);
          // Delay a bit since we use await with the session api and we cannot await the navigation methods
          await Future<void>.delayed(Duration(milliseconds: 100));

          verify(mockNative.startSession(ignoreDuration: true)).called(1);
          verify(mockNative.captureSession()).called(1);
        });

        test('starts new session on didPush in initial route', () async {
          _setupWebSessionIntegration();
          final toRoute = route(RouteSettings(name: '/'));

          final sut = _getSut();

          sut.didPush(toRoute, null);
          // Delay a bit since we use await with the session api and we cannot await the navigation methods
          await Future<void>.delayed(Duration(milliseconds: 100));

          verify(mockNative.startSession(ignoreDuration: true)).called(1);
          verify(mockNative.captureSession()).called(1);
        });

        test('does not start new session when navigating to the same route',
            () async {
          final fromRoute = route(RouteSettings(name: 'Same Route'));
          final toRoute = route(RouteSettings(name: 'Same Route'));

          final sut = _getSut();

          sut.didPush(fromRoute, toRoute);
          sut.didPop(fromRoute, toRoute);
          sut.didReplace(newRoute: toRoute, oldRoute: fromRoute);
          // Delay a bit since we use await with the session api and we cannot await the navigation methods
          await Future<void>.delayed(Duration(milliseconds: 100));

          verifyNever(mockNative.startSession(ignoreDuration: true));
          verifyNever(mockNative.captureSession());
        });
      });
    });
  });

  group('time to display', () {
    test('didPush sets transactionId', () {
      final mockHub = _MockHub();

      final tracer = getMockSentryTracer();
      _whenAnyStart(mockHub, tracer);

      final sut = fixture.getSut(
        hub: mockHub,
        autoFinishAfter: Duration(seconds: 5),
      );

      sut.didPush(route(RouteSettings(name: 'To Route')), null);

      verify(fixture.mockTimeToDisplayTracker.transactionId = any).called(1);
    });

    test('didPush calls track with transaction', () async {
      final mockHub = _MockHub();

      final tracer = getMockSentryTracer();
      _whenAnyStart(mockHub, tracer);

      final sut = fixture.getSut(
        hub: mockHub,
        autoFinishAfter: Duration(seconds: 5),
      );

      sut.didPush(route(RouteSettings(name: 'To Route')), null);
      // Delay a bit since we use await with the session api and we cannot await the navigation methods
      await Future<void>.delayed(Duration(milliseconds: 100));

      verify(fixture.mockTimeToDisplayTracker.track(tracer)).called(1);
    });

    test('didPush does not call track if transaction is null', () async {
      final mockHub = _MockHub();

      final noOpSpan = NoOpSentrySpan();
      _whenAnyStart(mockHub, noOpSpan);

      final sut = fixture.getSut(
        hub: mockHub,
        autoFinishAfter: Duration(seconds: 5),
      );

      sut.didPush(route(RouteSettings(name: 'To Route')), null);
      // Delay a bit since we use await with the session api and we cannot await the navigation methods
      await Future<void>.delayed(Duration(milliseconds: 100));

      verifyNever(fixture.mockTimeToDisplayTracker.track(any));
    });

    test('didPush calls clear', () async {
      final mockHub = _MockHub();

      final tracer = getMockSentryTracer();
      _whenAnyStart(mockHub, tracer);

      final sut = fixture.getSut(
        hub: mockHub,
      );

      sut.didPush(route(RouteSettings(name: 'To Route')), null);
      // Delay a bit since we use await with the session api and we cannot await the navigation methods
      await Future<void>.delayed(Duration(milliseconds: 100));

      verify(fixture.mockTimeToDisplayTracker.clear()).called(1);
    });
  });
}

class Fixture {
  late MockTimeToDisplayTracker mockTimeToDisplayTracker =
      MockTimeToDisplayTracker();

  SentryNavigatorObserver getSut({
    required Hub hub,
    bool enableAutoTransactions = true,
    Duration autoFinishAfter = const Duration(seconds: 1),
    bool setRouteNameAsTransaction = false,
    RouteNameExtractor? routeNameExtractor,
    AdditionalInfoExtractor? additionalInfoProvider,
    List<String>? ignoreRoutes,
  }) {
    if (hub is MockHub) {
      when(hub.generateNewTrace()).thenAnswer((_) => {});
    }
    final options = hub.options;
    if (options is SentryFlutterOptions) {
      options.timeToDisplayTracker = mockTimeToDisplayTracker;
    }
    return SentryNavigatorObserver(
      hub: hub,
      enableAutoTransactions: enableAutoTransactions,
      autoFinishAfter: autoFinishAfter,
      setRouteNameAsTransaction: setRouteNameAsTransaction,
      routeNameExtractor: routeNameExtractor,
      additionalInfoProvider: additionalInfoProvider,
      ignoreRoutes: ignoreRoutes,
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

MockSentryTracer getMockSentryTracer({String? name, bool? finished}) {
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
