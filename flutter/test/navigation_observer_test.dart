import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'mocks.dart';

void main() {
  group('NavigationBreadcrumb', () {
    test('happy path with string route agrument', () {
      const fromRouteSettings = RouteSettings(
        name: 'from',
        arguments: 'PageTitle',
      );

      const toRouteSettings = RouteSettings(
        name: 'to',
        arguments: 'PageTitle2',
      );

      final breadcrumb = NavigationBreadcrumb(
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

      final breadcrumb = NavigationBreadcrumb(
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
      final breadcrumb = NavigationBreadcrumb(
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
      final breadcrumb = NavigationBreadcrumb(
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
      final breadcrumb = NavigationBreadcrumb(
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

  group('SentryNavigationObserver', () {
    PageRoute route(RouteSettings settings) => PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => null,
          settings: settings,
        );

    RouteSettings routeSettings(String name, [Object arguments]) =>
        RouteSettings(name: name, arguments: arguments);

    test('Test recording of Breadcrumbs', () {
      final hub = MockHub();
      final observer = SentryNavigatorObserver(hub: hub);

      final to = routeSettings('to', 'foobar');
      final previous = routeSettings('previous', 'foobar');

      observer.didPush(route(to), route(previous));

      final dynamic breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;
      expect(
        breadcrumb.data,
        NavigationBreadcrumb(
          navigationType: 'didPush',
          from: previous,
          to: to,
        ).data,
      );
    });

    test('No arguments', () {
      final hub = MockHub();
      final observer = SentryNavigatorObserver(hub: hub);

      final to = routeSettings('to');
      final previous = routeSettings('previous');

      observer.didPush(route(to), route(previous));

      final dynamic breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;
      expect(
        breadcrumb.data,
        NavigationBreadcrumb(
          navigationType: 'didPush',
          from: previous,
          to: to,
        ).data,
      );
    });

    test('No arguments & no name', () {
      final hub = MockHub();
      final observer = SentryNavigatorObserver(hub: hub);

      final to = route(null);
      final previous = route(null);

      observer.didPush(to, previous);

      final dynamic breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;
      expect(
        breadcrumb.data,
        NavigationBreadcrumb(
          navigationType: 'didPush',
        ).data,
      );
    });

    test('No RouteSettings', () {
      PageRoute route() => PageRouteBuilder<void>(
            pageBuilder: (_, __, ___) => null,
          );

      final hub = MockHub();
      final observer = SentryNavigatorObserver(hub: hub);

      final to = route();
      final previous = route();

      observer.didPush(to, previous);

      final dynamic breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;
      expect(
        breadcrumb.data,
        NavigationBreadcrumb(
          navigationType: 'didPush',
        ).data,
      );
    });
  });
}
