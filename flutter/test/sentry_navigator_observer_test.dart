import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/sentry_native.dart';
import 'package:sentry_flutter/src/sentry_native_channel.dart';
import 'package:sentry/src/sentry_tracer.dart';

import 'mocks.dart';
import 'mocks.mocks.dart';

void main() {
  late Fixture fixture;

  PageRoute route(RouteSettings? settings) => PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => Container(),
        settings: settings,
      );

  void _whenAnyStart(MockHub mockHub, ISentrySpan thenReturnSpan,
      {String? name}) {
    when(mockHub.startTransaction(
      name ?? any,
      any,
      description: anyNamed('description'),
      bindToScope: anyNamed('bindToScope'),
      waitForChildren: anyNamed('waitForChildren'),
      autoFinishAfter: anyNamed('autoFinishAfter'),
      trimEnd: anyNamed('trimEnd'),
      onFinish: anyNamed('onFinish'),
      customSamplingContext: anyNamed('customSamplingContext'),
    )).thenReturn(thenReturnSpan);
  }

  setUp(() {
    SentryNative().reset();
    fixture = Fixture();
  });

  tearDown(() {
    SentryNative().reset();
  });

  group('NativeFrames', () {
    test('transaction start begins frames collection', () {
      final currentRoute = route(RouteSettings(name: 'Current Route'));
      final mockHub = _MockHub();
      final native = SentryNative();
      final mockNativeChannel = MockNativeChannel();
      native.setNativeChannel(mockNativeChannel);

      final tracer = MockNoOpSentrySpan();
      _whenAnyStart(mockHub, tracer);

      final sut = fixture.getSut(hub: mockHub);

      sut.didPush(currentRoute, null);

      expect(mockNativeChannel.numberOfBeginNativeFramesCalls, 1);
    });

    test('transaction finish adds native frames to tracer', () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final options = SentryOptions(dsn: fakeDsn);
      options.tracesSampleRate = 1;
      final hub = Hub(options);

      final nativeFrames = NativeFrames(3, 2, 1);
      final mockNativeChannel = MockNativeChannel();
      mockNativeChannel.nativeFrames = nativeFrames;

      final mockNative = SentryNative();
      mockNative.setNativeChannel(mockNativeChannel);

      final sut = fixture.getSut(
        hub: hub,
        autoFinishAfter: Duration(milliseconds: 10),
      );

      sut.didPush(currentRoute, null);

      // Get ref to created transaction
      // ignore: invalid_use_of_internal_member
      SentryTracer? actualTransaction;
      hub.configureScope((scope) {
        // ignore: invalid_use_of_internal_member
        actualTransaction = scope.span as SentryTracer;
      });

      await Future.delayed(Duration(milliseconds: 20));

      expect(mockNativeChannel.numberOfEndNativeFramesCalls, 1);

      final measurements = actualTransaction?.measurements ?? [];

      expect(measurements.length, 3);

      final expectedTotal = SentryMeasurement.totalFrames(3);
      final expectedSlow = SentryMeasurement.slowFrames(2);
      final expectedFrozen = SentryMeasurement.frozenFrames(1);

      for (final measurement in measurements) {
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

  group('RouteObserverTransaction', () {
    test('didPush starts transaction', () {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = _MockHub();
      final span = MockNoOpSentrySpan();
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(
        hub: hub,
        autoFinishAfter: Duration(seconds: 5),
      );

      sut.didPush(currentRoute, null);

      verify(hub.startTransaction(
        'Current Route',
        'navigation',
        waitForChildren: true,
        autoFinishAfter: Duration(seconds: 5),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      ));

      hub.configureScope((scope) {
        expect(scope.span, span);
      });
    });

    test('route with empty name does not start transaction', () {
      final currentRoute = route(null);

      final hub = _MockHub();
      final span = MockNoOpSentrySpan();
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(currentRoute, null);

      verifyNever(hub.startTransaction(
        'Current Route',
        'navigation',
        waitForChildren: true,
        autoFinishAfter: Duration(seconds: 3),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      ));

      hub.configureScope((scope) {
        expect(scope.span, null);
      });
    });

    test('no transaction on opt-out', () {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = _MockHub();
      final span = MockNoOpSentrySpan();
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub, enableAutoTransactions: false);

      sut.didPush(currentRoute, null);

      verifyNever(hub.startTransaction(
        'Current Route',
        'navigation',
        waitForChildren: true,
        autoFinishAfter: Duration(seconds: 3),
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

      final span = MockNoOpSentrySpan();
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(currentRoute, null);

      verify(hub.startTransaction(
        'Current Route',
        'navigation',
        waitForChildren: true,
        autoFinishAfter: Duration(seconds: 3),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      ));

      hub.configureScope((scope) {
        expect(scope.span, NoOpSentrySpan());
      });
    });

    test('didPush finishes previous transaction', () {
      final firstRoute = route(RouteSettings(name: 'First Route'));
      final secondRoute = route(RouteSettings(name: 'Second Route'));

      final hub = _MockHub();
      final span = MockNoOpSentrySpan();
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.status).thenReturn(null);
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(firstRoute, null);
      sut.didPush(secondRoute, firstRoute);

      verify(span.status = SpanStatus.ok());
      verify(span.finish());
    });

    test('didPop finishes transaction', () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = _MockHub();
      final span = MockNoOpSentrySpan();
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.status).thenReturn(null);
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(currentRoute, null);
      sut.didPop(currentRoute, null);

      verify(span.status = SpanStatus.ok());
      verify(span.finish());
    });

    test('didPop re-starts previous', () {
      final previousRoute = route(RouteSettings(name: 'Previous Route'));
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = _MockHub();
      final previousSpan = MockNoOpSentrySpan();
      when(previousSpan.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(previousSpan.status).thenReturn(null);
      _whenAnyStart(hub, previousSpan, name: 'Previous Route');

      final sut = fixture.getSut(hub: hub);

      sut.didPop(currentRoute, previousRoute);

      verify(hub.startTransaction(
        'Previous Route',
        'navigation',
        waitForChildren: true,
        autoFinishAfter: Duration(seconds: 3),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      ));

      hub.configureScope((scope) {
        expect(scope.span, previousSpan);
      });
    });

    test('didPush push multiple finishes previous', () async {
      final firstRoute = route(RouteSettings(name: 'First Route'));
      final secondRoute = route(RouteSettings(name: 'Second Route'));

      final hub = _MockHub();
      final firstSpan = MockNoOpSentrySpan();
      when(firstSpan.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(firstSpan.status).thenReturn(null);

      final secondSpan = MockNoOpSentrySpan();
      when(secondSpan.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(secondSpan.status).thenReturn(null);

      _whenAnyStart(hub, firstSpan, name: 'First Route');
      _whenAnyStart(hub, secondSpan, name: 'Second Route');

      final sut = fixture.getSut(hub: hub);

      sut.didPush(firstRoute, null);
      sut.didPush(secondRoute, firstRoute);

      verify(firstSpan.status = SpanStatus.ok());
      verify(firstSpan.finish());
    });

    test('route arguments are set on transaction', () {
      final arguments = {'foo': 'bar'};
      final currentRoute = route(RouteSettings(
        name: 'Current Route',
        arguments: arguments,
      ));

      final hub = _MockHub();
      final span = MockNoOpSentrySpan();
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.status).thenReturn(null);
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(currentRoute, null);

      verify(span.setData('route_settings_arguments', arguments));
    });

    test('flutter root name is replaced', () {
      final rootRoute = route(RouteSettings(name: '/'));

      final hub = _MockHub();
      final span = MockNoOpSentrySpan();
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(rootRoute, null);

      verify(hub.startTransaction(
        'root ("/")',
        'navigation',
        waitForChildren: true,
        autoFinishAfter: Duration(seconds: 3),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      ));

      hub.configureScope((scope) {
        expect(scope.span, span);
      });
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
      final hub = MockHub();
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
      final hub = MockHub();
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
      final hub = MockHub();
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
      PageRoute route() => PageRouteBuilder<void>(
            pageBuilder: (_, __, ___) => Container(),
          );

      final hub = MockHub();
      final observer = fixture.getSut(hub: hub);

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
      final hub = MockHub();
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
      final hub = MockHub();
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
  });
}

class Fixture {
  SentryNavigatorObserver getSut({
    required Hub hub,
    bool enableAutoTransactions = true,
    Duration autoFinishAfter = const Duration(seconds: 3),
    bool setRouteNameAsTransaction = false,
    RouteNameExtractor? routeNameExtractor,
    AdditionalInfoExtractor? additionalInfoProvider,
  }) {
    return SentryNavigatorObserver(
      hub: hub,
      enableAutoTransactions: enableAutoTransactions,
      autoFinishAfter: autoFinishAfter,
      setRouteNameAsTransaction: setRouteNameAsTransaction,
      routeNameExtractor: routeNameExtractor,
      additionalInfoProvider: additionalInfoProvider,
    );
  }

  SentrySpanContext mockContext() {
    return SentrySpanContext(operation: 'op');
  }
}

class _MockHub extends MockHub {
  final Scope scope = Scope(SentryOptions(dsn: fakeDsn));
  @override
  void configureScope(ScopeCallback? callback) {
    callback?.call(scope);
  }
}
