import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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
    PageRoute route(String name, [Object arguments]) => PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => null,
          settings: RouteSettings(name: name, arguments: arguments),
        );

    test('Test recording of Breadcrumbs', () {
      final hub = _FakeHub();
      final observer = SentryNavigatorObserver(hub: hub);

      final to = route('to', 'foobar');
      final previous = route('previous', 'foobar');

      observer.didPush(to, previous);

      expect(hub.breadcrumbs.length, 1);
      expect(hub.breadcrumbs.first.data, <String, dynamic>{
        'state': 'didPush',
        'from': 'previous',
        'from_arguments': 'foobar',
        'to': 'to',
        'to_arguments': 'foobar',
      });
    });

    test('No arguments', () {
      final hub = _FakeHub();
      final observer = SentryNavigatorObserver(hub: hub);

      final to = route('to');
      final previous = route('previous');

      observer.didPush(to, previous);

      expect(hub.breadcrumbs.length, 1);
      expect(hub.breadcrumbs.first.data, <String, dynamic>{
        'state': 'didPush',
        'from': 'previous',
        'to': 'to',
      });
    });

    test('No arguments & no name', () {
      final hub = _FakeHub();
      final observer = SentryNavigatorObserver(hub: hub);

      final to = route(null);
      final previous = route(null);

      observer.didPush(to, previous);

      expect(hub.breadcrumbs.length, 1);
      expect(hub.breadcrumbs.first.data, <String, dynamic>{
        'state': 'didPush',
      });
    });

    test('No RouteSettings', () {
      PageRoute route() => PageRouteBuilder<void>(
            pageBuilder: (_, __, ___) => null,
          );

      final hub = _FakeHub();
      final observer = SentryNavigatorObserver(hub: hub);

      final to = route();
      final previous = route();

      observer.didPush(to, previous);

      expect(hub.breadcrumbs.length, 1);
      expect(hub.breadcrumbs.first.data, <String, dynamic>{
        'state': 'didPush',
      });
    });
  });
}

/// Used to test if breadcrumbs are really added.
class _FakeHub implements Hub {
  List<Breadcrumb> breadcrumbs = [];

  @override
  void addBreadcrumb(Breadcrumb crumb, {dynamic hint}) {
    assert(crumb != null);
    breadcrumbs.add(crumb);
  }

  @override
  void bindClient(SentryClient client) {
    throw UnimplementedError();
  }

  @override
  Future<SentryId> captureEvent(SentryEvent event,
      {dynamic stackTrace, dynamic hint}) {
    throw UnimplementedError();
  }

  @override
  Future<SentryId> captureException(dynamic throwable,
      {dynamic stackTrace, dynamic hint}) {
    throw UnimplementedError();
  }

  @override
  Future<SentryId> captureMessage(String message,
      {SentryLevel level = SentryLevel.info,
      String template,
      List params,
      dynamic hint}) {
    throw UnimplementedError();
  }

  @override
  Hub clone() {
    throw UnimplementedError();
  }

  @override
  void close() {
    throw UnimplementedError();
  }

  @override
  void configureScope(callback) {
    throw UnimplementedError();
  }

  @override
  // TODO: implement isEnabled
  bool get isEnabled => throw UnimplementedError();

  @override
  // TODO: implement lastEventId
  SentryId get lastEventId => throw UnimplementedError();
}
