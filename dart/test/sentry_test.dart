import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'fake_platform_checker.dart';

Function appRunner = () {};

void main() {
  group('Sentry capture methods', () {
    SentryClient client;

    Exception anException;

    setUp(() async {
      await Sentry.init((options) => options.dsn = fakeDsn);
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

    test('should capture message', () async {
      await Sentry.captureMessage(fakeMessage.formatted,
          level: SentryLevel.warning);
      verify(
        client.captureMessage(
          fakeMessage.formatted,
          level: SentryLevel.warning,
          scope: anyNamed('scope'),
        ),
      ).called(1);
    });
  });

  group('Sentry is enabled or disabled', () {
    tearDown(() {
      Sentry.close();
    });
    test('null DSN', () {
      expect(
        () async => await Sentry.init((options) => options.dsn = null),
        throwsArgumentError,
      );
      expect(Sentry.isEnabled, false);
    });

    test('appRunner should be optional', () async {
      expect(Sentry.isEnabled, false);
      await Sentry.init((options) => options.dsn = fakeDsn);
      expect(Sentry.isEnabled, true);
    });

    test('empty DSN', () async {
      await Sentry.init((options) => options.dsn = '');
      expect(Sentry.isEnabled, false);
    });

    test('close disables the SDK', () async {
      await Sentry.init((options) => options.dsn = fakeDsn);

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
      final integration = MockIntegration();

      await Sentry.init(
        (options) {
          options.dsn = fakeDsn;
          options.addIntegration(integration);
        },
      );

      verify(integration(any, any)).called(1);
    });

    test('should add default integrations', () async {
      SentryOptions optionsReference;
      await Sentry.init(
        (options) {
          options.dsn = fakeDsn;
          optionsReference = options;
        },
        appRunner: appRunner,
      );
      expect(
        optionsReference.integrations
            .whereType<IsolateErrorIntegration>()
            .length,
        1,
      );
      expect(
        optionsReference.integrations
            .whereType<RunZonedGuardedIntegration>()
            .length,
        1,
      );
    }, onPlatform: {'browser': Skip()});

    test('should add only web compatible default integrations', () async {
      await Sentry.init(
        (options) {
          options.dsn = fakeDsn;
          expect(
            options.integrations.whereType<IsolateErrorIntegration>().length,
            0,
          );
        },
      );
    }, onPlatform: {'vm': Skip()});

    test('should close integrations', () async {
      final integration = MockIntegration();

      await Sentry.init(
        (options) {
          options.dsn = fakeDsn;
          options.addIntegration(integration);
        },
      );

      Sentry.close();

      verify(integration(any, any)).called(1);
      verify(integration.close()).called(1);
    });
  });

  test(
    "options can't be null",
    () {
      expect(
          () async => await Sentry.init(
                (options) => options = null,
              ),
          throwsArgumentError);
    },
  );

  test('options.environment debug', () async {
    final sentryOptions = SentryOptions()
      ..platformChecker = FakePlatformChecker.debugMode();

    await Sentry.init((options) {
      options.dsn = fakeDsn;
      expect(options.environment, 'debug');
    }, options: sentryOptions);
  });

  test('options.environment profile', () async {
    final sentryOptions = SentryOptions()
      ..platformChecker = FakePlatformChecker.profileMode();
    await Sentry.init((options) {
      options.dsn = fakeDsn;
      expect(options.environment, 'profile');
    }, options: sentryOptions);
  });

  test('options.environment production (defaultEnvironment)', () async {
    final sentryOptions = SentryOptions()
      ..platformChecker = FakePlatformChecker.releaseMode();
    await Sentry.init((options) {
      options.dsn = fakeDsn;
      expect(options.environment, defaultEnvironment);
    }, options: sentryOptions);
  });
}
