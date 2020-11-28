import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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
      expect(breadcrumb.type, 'didPush');
      expect(breadcrumb.data, <String, dynamic>{
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
      expect(breadcrumb.type, 'didPush');
      expect(breadcrumb.data, <String, dynamic>{
        'from': 'from',
        'from_arguments': 'PageTitle',
        'to': 'to',
        'to_arguments': {
          'foo': '123',
          'bar': 'foobar',
        },
      });
    });
  });

  group('SentryNavigationObserver', () {
    PageRoute route(String name, [Object arguments]) => PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => null,
          settings: RouteSettings(name: name, arguments: arguments),
        );

    test('Test recording of Breadcrumbs', () {
      final hub = MockHub();
      final observer = SentryNavigatorObserver(hub);

      var to = route('to', 'foobar');

      var previous = route('previous', 'foobar');

      observer.didPush(to, previous);

      // TODO how to test if breadcrumb was added?
    });
  });
}
