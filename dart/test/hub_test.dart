import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/hub.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_sentry_client.dart';

void main() {
  bool scopeEquals(Scope? a, Scope b) {
    return identical(a, b) ||
        a!.level == b.level &&
            a.transaction == b.transaction &&
            a.user == b.user &&
            IterableEquality().equals(a.fingerprint, b.fingerprint) &&
            IterableEquality().equals(a.breadcrumbs, b.breadcrumbs) &&
            MapEquality().equals(a.tags, b.tags) &&
            MapEquality().equals(a.extra, b.extra);
  }

  group('Hub instantiation', () {
    test('should instantiate with a dsn', () {
      final hub = Hub(SentryOptions(dsn: fakeDsn));
      expect(hub.isEnabled, true);
    });
  });

  group('Hub captures', () {
    var options = SentryOptions(dsn: fakeDsn);
    var hub = Hub(options);
    var client = MockSentryClient();

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      hub = Hub(options);
      client = MockSentryClient();
      hub.bindClient(client);
    });

    test(
      'should capture event with the default scope',
      () async {
        await hub.captureEvent(fakeEvent);

        var scope = client.captureEventCalls.first.scope;

        expect(
          client.captureEventCalls.first.event,
          fakeEvent,
        );

        expect(scopeEquals(scope, Scope(options)), true);
      },
    );

    test('should capture exception', () async {
      await hub.captureException(fakeException);

      expect(client.captureExceptionCalls.length, 1);
      expect(
        client.captureExceptionCalls.first.throwable,
        fakeException,
      );
      expect(client.captureExceptionCalls.first.scope, isNotNull);
    });

    test('should capture message', () async {
      await hub.captureMessage(
        fakeMessage.formatted,
        level: SentryLevel.warning,
      );

      expect(client.captureMessageCalls.length, 1);
      expect(client.captureMessageCalls.first.formatted, fakeMessage.formatted);
      expect(client.captureMessageCalls.first.level, SentryLevel.warning);
      expect(client.captureMessageCalls.first.scope, isNotNull);
    });

    test('should save the lastEventId', () async {
      final event = SentryEvent();
      final eventId = event.eventId;
      final returnedId = await hub.captureEvent(event);
      expect(eventId.toString(), returnedId.toString());
    });
  });

  group('Hub scope', () {
    var hub = Hub(SentryOptions(dsn: fakeDsn));
    var client = MockSentryClient();

    setUp(() {
      hub = Hub(SentryOptions(dsn: fakeDsn));
      client = MockSentryClient();
      hub.bindClient(client);
    });

    test('should configure its scope', () async {
      hub.configureScope((Scope scope) {
        scope
          ..user = fakeUser
          ..level = SentryLevel.debug
          ..fingerprint = ['1', '2'];
      });
      await hub.captureEvent(fakeEvent);

      expect(client.captureEventCalls.isNotEmpty, true);
      expect(client.captureEventCalls.first.event, fakeEvent);
      expect(client.captureEventCalls.first.scope, isNotNull);
      final scope = client.captureEventCalls.first.scope;

      expect(
        scopeEquals(
          scope,
          Scope(SentryOptions(dsn: fakeDsn))
            ..level = SentryLevel.debug
            ..user = fakeUser
            ..fingerprint = ['1', '2'],
        ),
        true,
      );
    });

    test('should add breadcrumb to current Scope', () {
      hub.configureScope((Scope scope) {
        expect(0, scope..breadcrumbs.length);
      });
      hub.addBreadcrumb(Breadcrumb(message: 'test'));
      hub.configureScope((Scope scope) {
        expect(1, scope..breadcrumbs.length);
        expect('test', scope..breadcrumbs.first.message);
      });
    });
  });

  group('Hub Client', () {
    late Hub hub;
    late SentryClient client;
    SentryOptions options;

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      hub = Hub(options);
      client = MockSentryClient();
      hub.bindClient(client);
    });

    test('should bind a new client', () async {
      final client2 = MockSentryClient();
      hub.bindClient(client2);
      await hub.captureEvent(fakeEvent);
      expect(client2.captureEventCalls.length, 1);
      expect(client2.captureEventCalls.first.event, fakeEvent);
      expect(client2.captureEventCalls.first.scope, isNotNull);
    });

    test('should close its client', () async {
      await hub.close();

      expect(hub.isEnabled, false);
      expect((client as MockSentryClient).closeCalls, 1);
    });
  });

  test('clones', () {
    // TODO I'm not sure how to test it
    // could we set [hub.stack] as @visibleForTesting ?
  });
}
