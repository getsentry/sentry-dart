import 'dart:async';

import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

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

  test('sets $SentryUser', () {
    final sut = fixture.getSut();

    final user = SentryUser(id: 'test');
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

    final user = SentryUser(id: 'test');
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

    expect(sut.fingerprint.length, 0);

    expect(sut.tags.length, 0);

    expect(sut.extra.length, 0);

    expect(sut.eventProcessors.length, 0);
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

  group('Scope apply', () {
    final scopeUser = SentryUser(
      id: '800',
      username: 'first-user',
      email: 'first@user.lan',
      ipAddress: '127.0.0.1',
      extras: const <String, String>{'first-sign-in': '2020-01-01'},
    );

    final breadcrumb = Breadcrumb(message: 'Authenticated');

    test('apply context to event', () async {
      final event = SentryEvent(
        tags: const {'etag': '987'},
        extra: const {'e-infos': 'abc'},
      );
      final scope = Scope(SentryOptions(dsn: fakeDsn))
        ..user = scopeUser
        ..fingerprint = ['example-dart']
        ..addBreadcrumb(breadcrumb)
        ..transaction = '/example/app'
        ..level = SentryLevel.warning
        ..setTag('build', '579')
        ..setExtra('company-name', 'Dart Inc')
        ..setContexts('theme', 'material')
        ..addEventProcessor(
          (event, {hint}) => event..tags?.addAll({'page-locale': 'en-us'}),
        );

      final updatedEvent = await scope.applyToEvent(event, null);

      expect(updatedEvent?.user, scopeUser);
      expect(updatedEvent?.transaction, '/example/app');
      expect(updatedEvent?.fingerprint, ['example-dart']);
      expect(updatedEvent?.breadcrumbs, [breadcrumb]);
      expect(updatedEvent?.level, SentryLevel.warning);
      expect(updatedEvent?.tags,
          {'etag': '987', 'build': '579', 'page-locale': 'en-us'});
      expect(
          updatedEvent?.extra, {'e-infos': 'abc', 'company-name': 'Dart Inc'});
      expect(updatedEvent?.contexts['theme'], {'value': 'material'});
    });

    test('should not apply the scope properties when event already has it ',
        () async {
      final eventUser = SentryUser(id: '123');
      final eventBreadcrumb = Breadcrumb(message: 'event-breadcrumb');

      final event = SentryEvent(
        transaction: '/event/transaction',
        user: eventUser,
        fingerprint: ['event-fingerprint'],
        breadcrumbs: [eventBreadcrumb],
      );
      final scope = Scope(SentryOptions(dsn: fakeDsn))
        ..user = scopeUser
        ..fingerprint = ['example-dart']
        ..addBreadcrumb(breadcrumb)
        ..transaction = '/example/app';

      final updatedEvent = await scope.applyToEvent(event, null);

      expect(updatedEvent?.user, eventUser);
      expect(updatedEvent?.transaction, '/event/transaction');
      expect(updatedEvent?.fingerprint, ['event-fingerprint']);
      expect(updatedEvent?.breadcrumbs, [eventBreadcrumb]);
    });

    test(
        'should not apply the scope.contexts values if the event already has it',
        () async {
      final event = SentryEvent(
        contexts: Contexts(
          device: SentryDevice(name: 'event-device'),
          app: SentryApp(name: 'event-app'),
          gpu: Gpu(name: 'event-gpu'),
          runtimes: [SentryRuntime(name: 'event-runtime')],
          browser: SentryBrowser(name: 'event-browser'),
          operatingSystem: OperatingSystem(name: 'event-os'),
        ),
      );
      final scope = Scope(SentryOptions(dsn: fakeDsn))
        ..setContexts(
          SentryDevice.type,
          SentryDevice(name: 'context-device'),
        )
        ..setContexts(
          SentryApp.type,
          SentryApp(name: 'context-app'),
        )
        ..setContexts(
          Gpu.type,
          Gpu(name: 'context-gpu'),
        )
        ..setContexts(
          SentryRuntime.listType,
          [SentryRuntime(name: 'context-runtime')],
        )
        ..setContexts(
          SentryBrowser.type,
          SentryBrowser(name: 'context-browser'),
        )
        ..setContexts(
          OperatingSystem.type,
          OperatingSystem(name: 'context-os'),
        );

      final updatedEvent = await scope.applyToEvent(event, null);

      expect(updatedEvent?.contexts[SentryDevice.type].name, 'event-device');
      expect(updatedEvent?.contexts[SentryApp.type].name, 'event-app');
      expect(updatedEvent?.contexts[Gpu.type].name, 'event-gpu');
      expect(updatedEvent?.contexts[SentryRuntime.listType].first.name,
          'event-runtime');
      expect(updatedEvent?.contexts[SentryBrowser.type].name, 'event-browser');
      expect(updatedEvent?.contexts[OperatingSystem.type].name, 'event-os');
    });

    test('should apply the scope.contexts values ', () async {
      final event = SentryEvent();
      final scope = Scope(SentryOptions(dsn: fakeDsn))
        ..setContexts(SentryDevice.type, SentryDevice(name: 'context-device'))
        ..setContexts(SentryApp.type, SentryApp(name: 'context-app'))
        ..setContexts(Gpu.type, Gpu(name: 'context-gpu'))
        ..setContexts(
            SentryRuntime.listType, [SentryRuntime(name: 'context-runtime')])
        ..setContexts(
            SentryBrowser.type, SentryBrowser(name: 'context-browser'))
        ..setContexts(OperatingSystem.type, OperatingSystem(name: 'context-os'))
        ..setContexts('theme', 'material')
        ..setContexts('version', 9)
        ..setContexts('location', {'city': 'London'});

      final updatedEvent = await scope.applyToEvent(event, null);

      expect(updatedEvent?.contexts[SentryDevice.type].name, 'context-device');
      expect(updatedEvent?.contexts[SentryApp.type].name, 'context-app');
      expect(updatedEvent?.contexts[Gpu.type].name, 'context-gpu');
      expect(
        updatedEvent?.contexts[SentryRuntime.listType].first.name,
        'context-runtime',
      );
      expect(
          updatedEvent?.contexts[SentryBrowser.type].name, 'context-browser');
      expect(updatedEvent?.contexts[OperatingSystem.type].name, 'context-os');
      expect(updatedEvent?.contexts['theme']['value'], 'material');
      expect(updatedEvent?.contexts['version']['value'], 9);
      expect(updatedEvent?.contexts['location'], {'city': 'London'});
    });

    test('should apply the scope level', () async {
      final event = SentryEvent(level: SentryLevel.warning);
      final scope = Scope(SentryOptions(dsn: fakeDsn))
        ..level = SentryLevel.error;

      final updatedEvent = await scope.applyToEvent(event, null);

      expect(updatedEvent?.level, SentryLevel.error);
    });
  });

  test('event processor drops the event', () async {
    final sut = fixture.getSut();

    sut.addEventProcessor(fixture.processor);

    final event = SentryEvent();
    var newEvent = await sut.applyToEvent(event, null);

    expect(newEvent, isNull);
  });
}

class Fixture {
  Scope getSut({
    int maxBreadcrumbs = 100,
    BeforeBreadcrumbCallback? beforeBreadcrumbCallback,
  }) {
    final options = SentryOptions(dsn: fakeDsn);
    options.maxBreadcrumbs = maxBreadcrumbs;
    options.beforeBreadcrumb = beforeBreadcrumbCallback;
    return Scope(options);
  }

  FutureOr<SentryEvent?> processor(SentryEvent event, {dynamic hint}) {
    return null;
  }

  Breadcrumb? beforeBreadcrumbCallback(Breadcrumb? breadcrumb,
          {dynamic hint}) =>
      null;
}
