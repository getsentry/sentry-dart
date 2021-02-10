import 'dart:async';

import 'package:collection/collection.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/hub.dart';
import 'package:test/test.dart';

import 'mocks.dart';

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
    late Hub hub;
    late SentryOptions options;
    late MockSentryClient client;

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
        expect(
          scopeEquals(
            verify(
              client.captureEvent(
                fakeEvent,
                scope: captureAnyNamed('scope'),
              ),
            ).captured.first,
            Scope(options),
          ),
          true,
        );
      },
    );

    test('should capture exception', () async {
      await hub.captureException(fakeException);

      verify(client.captureException(fakeException, scope: anyNamed('scope')))
          .called(1);
    });

    test('should capture message', () async {
      await hub.captureMessage(fakeMessage.formatted, level: SentryLevel.info);
      verify(
        client.captureMessage(
          fakeMessage.formatted,
          level: SentryLevel.info,
          scope: anyNamed('scope'),
        ),
      ).called(1);
    });

    test('should save the lastEventId', () async {
      final event = SentryEvent();
      final eventId = event.eventId;
      when(client.captureEvent(
        event,
        scope: anyNamed('scope'),
        hint: anyNamed('hint'),
      )).thenAnswer((_) => Future.value(event.eventId));
      final returnedId = await hub.captureEvent(event);
      expect(eventId.toString(), returnedId.toString());
    });
  });

  group('Hub scope', () {
    late Hub hub;
    late SentryClient client;

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

      final scope = verify(
        client.captureEvent(
          fakeEvent,
          scope: captureAnyNamed('scope'),
        ),
      ).captured.first as Scope?;

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
      verify(
        client2.captureEvent(
          fakeEvent,
          scope: anyNamed('scope'),
        ),
      ).called(1);
    });

    test('should close its client', () {
      hub.close();

      expect(hub.isEnabled, false);
      verify(client.close()).called(1);
    });
  });

  test('clones', () {
    // TODO I'm not sure how to test it
    // could we set [hub.stack] as @visibleForTesting ?
  });
}
