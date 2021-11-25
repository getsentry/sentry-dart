import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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
      customSamplingContext: anyNamed('customSamplingContext'),
    )).thenReturn(thenReturnSpan);
  }

  setUp(() {
    fixture = Fixture();
  });

  group('RouteObserverTransaction', () {
    test('didPush starts transaction', () {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());
      final sut = fixture.getSut(hub: hub, setRouteNameAsTransaction: false);

      sut.didPush(currentRoute, null);

      verify(hub.startTransaction('Current Route', 'ui.load',
          description: null, bindToScope: true, customSamplingContext: null));
    });

    test('didPush finishes previous transaction', () {
      final firstRoute = route(RouteSettings(name: 'First Route'));
      final secondRoute = route(RouteSettings(name: 'Second Route'));

      final hub = MockHub();
      final span = MockNoOpSentrySpan();
      when(span.status).thenReturn(null);
      _whenAnyStart(hub, span);
      final sut = fixture.getSut(hub: hub, setRouteNameAsTransaction: false);

      sut.didPush(firstRoute, null);
      sut.didPush(secondRoute, firstRoute);

      verify(span.status = SpanStatus.ok());
      verify(span.finish());
    });

    test('didPush finishes transaction after timeout', () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = MockHub();
      final span = MockNoOpSentrySpan();
      when(span.status).thenReturn(null);
      _whenAnyStart(hub, span);
      final sut = fixture.getSut(hub: hub, setRouteNameAsTransaction: false);

      sut.didPush(currentRoute, null);

      await Future.delayed(Duration(milliseconds: 3100));

      verify(span.status = SpanStatus.ok());
      verify(span.finish());
    });

    test('didPop finishes transaction', () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = MockHub();
      final span = MockNoOpSentrySpan();
      when(span.status).thenReturn(null);
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub, setRouteNameAsTransaction: false);

      sut.didPush(currentRoute, null);
      sut.didPop(currentRoute, null);

      await Future.delayed(Duration(milliseconds: 3100));

      verify(span.status = SpanStatus.ok());
      verify(span.finish()).called(1);
    });

    test('didPush push multiple finishes transactions', () async {
      final firstRoute = route(RouteSettings(name: 'First Route'));
      final secondRoute = route(RouteSettings(name: 'Second Route'));

      final hub = MockHub();
      final firstSpan = MockNoOpSentrySpan();
      when(firstSpan.status).thenReturn(null);
      final secondSpan = MockNoOpSentrySpan();
      when(secondSpan.status).thenReturn(null);
      _whenAnyStart(hub, firstSpan, name: 'First Route');
      _whenAnyStart(hub, secondSpan, name: 'Second Route');
      final sut = fixture.getSut(hub: hub, setRouteNameAsTransaction: false);

      sut.didPush(firstRoute, null);
      sut.didPush(secondRoute, firstRoute);

      await Future.delayed(Duration(milliseconds: 3100));

      verify(firstSpan.status = SpanStatus.ok());
      verify(firstSpan.finish()).called(1);
      verify(secondSpan.status = SpanStatus.ok());
      verify(secondSpan.finish()).called(1);
    });

    test('route arguments are set on transaction',  () {
      final arguments = {'foo': 'bar'};
      final currentRoute = route(
          RouteSettings(
            name: 'Current Route',
            arguments: arguments,
          )
      );

      final hub = MockHub();
      final span = MockNoOpSentrySpan();
      when(span.status).thenReturn(null);
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub, setRouteNameAsTransaction: false);

      sut.didPush(currentRoute, null);

      verify(span.setData('route_settings_arguments', arguments));
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
      );

      expect(breadcrumb.category, 'navigation');
      expect(breadcrumb.data, <String, dynamic>{
        'state': 'didPush',
        'from': 'from',
        'from_arguments': 'PageTitle',
        'to': 'to',
        'to_arguments': 'PageTitle2',
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
  });
}

class Fixture {
  SentryNavigatorObserver getSut({
    required Hub hub,
    bool setRouteNameAsTransaction = false,
  }) {
    return SentryNavigatorObserver(
      hub: hub,
      setRouteNameAsTransaction: setRouteNameAsTransaction,
    );
  }
}

class _MockHub extends MockHub {
  final Scope scope = Scope(SentryOptions(dsn: fakeDsn));
  @override
  void configureScope(ScopeCallback? callback) {
    callback?.call(scope);
  }
}
