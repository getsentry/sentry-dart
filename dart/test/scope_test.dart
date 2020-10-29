import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

// TODO test context apply / clone

void main() {
  final fixture = Fixture();

  test('sets $SentryLevel', () {
    final sut = fixture.getSut();

    sut.level = SentryLevel.debug;

    expect(sut.level, SentryLevel.debug);
  });

  test('sets transaction', () {
    final sut = fixture.getSut();

    sut.transaction = 'test';

    expect(sut.transaction, 'test');
  });

  test('sets $User', () {
    final sut = fixture.getSut();

    final user = User(id: 'test');
    sut.user = user;

    expect(sut.user, user);
  });

  test('sets fingerprint', () {
    final sut = fixture.getSut();

    final fingerprints = ['test'];
    sut.fingerprint = fingerprints;

    expect(sut.fingerprint, fingerprints);
  });

  test('adds $Breadcrumb', () {
    final sut = fixture.getSut();

    final breadcrumb = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    sut.addBreadcrumb(breadcrumb);

    expect(sut.breadcrumbs.last, breadcrumb);
  });

  test('Executes and drops $Breadcrumb', () {
    final sut = fixture.getSut(
      beforeBreadcrumbCallback: fixture.beforeBreadcrumbCallback,
    );

    final breadcrumb = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    sut.addBreadcrumb(breadcrumb);

    expect(sut.breadcrumbs.length, 0);
  });

  test('adds $EventProcessor', () {
    final sut = fixture.getSut();

    sut.addEventProcessor(fixture.processor);

    expect(sut.eventProcessors.last, fixture.processor);
  });

  test('respects max $Breadcrumb', () {
    final maxBreadcrumbs = 2;
    final sut = fixture.getSut(maxBreadcrumbs: maxBreadcrumbs);

    final breadcrumb1 = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    final breadcrumb2 = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    final breadcrumb3 = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    sut.addBreadcrumb(breadcrumb1);
    sut.addBreadcrumb(breadcrumb2);
    sut.addBreadcrumb(breadcrumb3);

    expect(sut.breadcrumbs.length, maxBreadcrumbs);
  });

  test('rotates $Breadcrumb', () {
    final sut = fixture.getSut(maxBreadcrumbs: 2);

    final breadcrumb1 = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    final breadcrumb2 = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    final breadcrumb3 = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    sut.addBreadcrumb(breadcrumb1);
    sut.addBreadcrumb(breadcrumb2);
    sut.addBreadcrumb(breadcrumb3);

    expect(sut.breadcrumbs.first, breadcrumb2);

    expect(sut.breadcrumbs.last, breadcrumb3);
  });

  test('empty $Breadcrumb list', () {
    final maxBreadcrumbs = 0;
    final sut = fixture.getSut(maxBreadcrumbs: maxBreadcrumbs);

    final breadcrumb1 = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    sut.addBreadcrumb(breadcrumb1);

    expect(sut.breadcrumbs.length, maxBreadcrumbs);
  });

  test('clears $Breadcrumb list', () {
    final sut = fixture.getSut();

    final breadcrumb1 = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    sut.addBreadcrumb(breadcrumb1);
    sut.clear();

    expect(sut.breadcrumbs.length, 0);
  });

  test('sets tag', () {
    final sut = fixture.getSut();

    sut.setTag('test', 'test');

    expect(sut.tags['test'], 'test');
  });

  test('removes tag', () {
    final sut = fixture.getSut();

    sut.setTag('test', 'test');
    sut.removeTag('test');

    expect(sut.tags['test'], null);
  });

  test('sets extra', () {
    final sut = fixture.getSut();

    sut.setExtra('test', 'test');

    expect(sut.extra['test'], 'test');
  });

  test('removes extra', () {
    final sut = fixture.getSut();

    sut.setExtra('test', 'test');
    sut.removeExtra('test');

    expect(sut.extra['test'], null);
  });

  test('clears $Scope', () {
    final sut = fixture.getSut();

    final breadcrumb1 = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    sut.addBreadcrumb(breadcrumb1);

    sut.level = SentryLevel.debug;
    sut.transaction = 'test';

    final user = User(id: 'test');
    sut.user = user;

    final fingerprints = ['test'];
    sut.fingerprint = fingerprints;

    sut.setTag('test', 'test');
    sut.setExtra('test', 'test');

    sut.addEventProcessor(fixture.processor);

    sut.clear();

    expect(sut.breadcrumbs.length, 0);

    expect(sut.level, null);

    expect(sut.transaction, null);

    expect(sut.user, null);

    expect(sut.fingerprint, null);

    expect(sut.tags.length, 0);

    expect(sut.extra.length, 0);

    expect(sut.eventProcessors.length, 0);
  });

  test('apply context to event', () {
    final user = User(
      id: '800',
      username: 'first-user',
      email: 'first@user.lan',
      ipAddress: '127.0.0.1',
      extras: <String, String>{'first-sign-in': '2020-01-01'},
    );
    final breadcrumb = Breadcrumb(message: 'Authenticated');

    final event = SentryEvent();
    final scope = Scope(SentryOptions())
      ..user = user
      ..fingerprint = ['example-dart']
      ..addBreadcrumb(breadcrumb)
      ..transaction = '/example/app'
      ..level = SentryLevel.warning
      ..setTag('build', '579')
      ..setExtra('company-name', 'Dart Inc')
      ..setContexts(key: 'theme', value: 'material')
      ..addEventProcessor(
        (event, hint) => event..tags.addAll({'page-locale': 'en-us'}),
      );

    final updatedEvent = scope.applyToEvent(event, null);

    expect(updatedEvent.user, user);
    expect(updatedEvent.transaction, '/example/app');
    expect(updatedEvent.fingerprint, ['example-dart']);
    expect(updatedEvent.breadcrumbs, [breadcrumb]);
    expect(updatedEvent.level, SentryLevel.warning);
    expect(updatedEvent.tags, {'build': '579', 'page-locale': 'en-us'});
    expect(updatedEvent.extra, {'company-name': 'Dart Inc'});
    expect(updatedEvent.contexts['theme'], 'material');
  });

  test('clones', () {
    final sut = fixture.getSut();
    final clone = sut.clone();
    expect(sut.user, clone.user);
    expect(sut.transaction, clone.transaction);
    expect(sut.extra, clone.extra);
    expect(sut.tags, clone.tags);
    expect(sut.breadcrumbs, clone.breadcrumbs);
    expect(sut.contexts, clone.contexts);
    expect(ListEquality().equals(sut.fingerprint, clone.fingerprint), true);
    expect(
      ListEquality().equals(sut.eventProcessors, clone.eventProcessors),
      true,
    );
  });
}

class Fixture {
  Scope getSut({
    int maxBreadcrumbs = 100,
    BeforeBreadcrumbCallback beforeBreadcrumbCallback,
  }) {
    final options = SentryOptions();
    options.maxBreadcrumbs = maxBreadcrumbs;
    options.beforeBreadcrumb = beforeBreadcrumbCallback;
    return Scope(options);
  }

  SentryEvent processor(SentryEvent event, dynamic hint) => null;

  Breadcrumb beforeBreadcrumbCallback(Breadcrumb breadcrumb, dynamic hint) =>
      null;
}
