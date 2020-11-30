import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'mocks.dart';

Function appRunner = () {};

void main() {
  group('Sentry capture methods', () {
    SentryClient client;

    Exception anException;

    setUp(() async {
      await Sentry.init((options) => options.dsn = fakeDsn, appRunner);
      anException = Exception('anException');

      client = MockSentryClient();
      Sentry.bindClient(client);
    });
    tearDown(() {
      Sentry.close();
    });

    test('should capture the event', () async {
      await Sentry.captureEvent(fakeEvent);
      verify(
        client.captureEvent(
          fakeEvent,
          scope: anyNamed('scope'),
        ),
      ).called(1);
    });

    test('should not capture a null event', () async {
      await Sentry.captureEvent(null);
      verifyNever(client.captureEvent(fakeEvent));
    });

    test('should not capture a null exception', () async {
      await Sentry.captureException(null);
      verifyNever(
        client.captureException(
          any,
          stackTrace: anyNamed('stackTrace'),
        ),
      );
    });

    test('should capture the exception', () async {
      await Sentry.captureException(anException);
      verify(
        client.captureException(
          anException,
          stackTrace: null,
          scope: anyNamed('scope'),
        ),
      ).called(1);
    });
  });
  group('Sentry is enabled or disabled', () {
    test('null DSN', () {
      expect(
        () async =>
            await Sentry.init((options) => options.dsn = null, appRunner),
        throwsArgumentError,
      );
      expect(Sentry.isEnabled, false);
    });

    test('appRunner should be optional', () async {
      expect(Sentry.isEnabled, false);
      await Sentry.init((options) => options.dsn = fakeDsn, null);
      expect(Sentry.isEnabled, true);
    });

    test('empty DSN', () async {
      await Sentry.init((options) => options.dsn = '', appRunner);
      expect(Sentry.isEnabled, false);
    });

    test('close disables the SDK', () async {
      await Sentry.init((options) => options.dsn = fakeDsn, appRunner);

      Sentry.bindClient(MockSentryClient());

      expect(Sentry.isEnabled, true);

      Sentry.close();

      expect(Sentry.isEnabled, false);
    });
  });

  group('Sentry init', () {
    tearDown(() {
      Sentry.close();
    });

    test('should install integrations', () async {
      var called = false;
      void integration(Hub hub, SentryOptions options) => called = true;

      await Sentry.init(
        (options) {
          options.dsn = fakeDsn;
          options.addIntegration(integration);
        },
        appRunner,
      );

      expect(called, true);
    });

    test('should add initial integrations first', () async {
      await Sentry.init(
        (options) {
          options.dsn = fakeDsn;
          expect(options.integrations.first, initialIntegration);
        },
        appRunner,
        [initialIntegration],
      );
    });

    test('should add default integrations', () async {
      await Sentry.init(
        (options) {
          options.dsn = fakeDsn;
          expect(options.integrations.length, 2);
        },
        appRunner,
      );
    }, onPlatform: {'browser': Skip()});

    test('should add only web compatible default integrations', () async {
      await Sentry.init(
        (options) {
          options.dsn = fakeDsn;
          expect(options.integrations.length, 1);
        },
        appRunner,
      );
    }, onPlatform: {'vm': Skip()});
  });

  test(
    "options can't be null",
    () {
      expect(
          () async => await Sentry.init((options) => options = null, appRunner),
          throwsArgumentError);
    },
  );
}

void initialIntegration(Hub hub, SentryOptions options) {}
