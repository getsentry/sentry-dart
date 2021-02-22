import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'fake_platform_checker.dart';
import 'mocks/mock_integration.dart';
import 'mocks/mock_sentry_client.dart';

AppRunner appRunner = () {};

void main() {
  group('Sentry capture methods', () {
    var client = MockSentryClient();

    var anException = Exception();

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

      expect(client.captureEventCalls.length, 1);
      expect(client.captureEventCalls.first.event, fakeEvent);
      expect(client.captureEventCalls.first.scope, isNotNull);
    });

    test('should not capture a null exception', () async {
      await Sentry.captureException(null);
      expect(client.captureExceptionCalls.length, 0);
    });

    test('should capture the exception', () async {
      await Sentry.captureException(anException);
      expect(client.captureExceptionCalls.length, 1);
      expect(client.captureExceptionCalls.first.throwable, anException);
      expect(client.captureExceptionCalls.first.stackTrace, isNull);
      expect(client.captureExceptionCalls.first.scope, isNotNull);
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

      expect(integration.callCalls, 1);
    });

    test('should add default integrations', () async {
      late SentryOptions optionsReference;
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

      expect(integration.callCalls, 1);
      expect(integration.closeCalls, 1);
    });
  });

  test('options.environment debug', () async {
    final sentryOptions = SentryOptions(dsn: fakeDsn)
      ..platformChecker = FakePlatformChecker.debugMode();

    await Sentry.init((options) {
      options.dsn = fakeDsn;
      expect(options.environment, 'debug');
    }, options: sentryOptions);
  });

  test('options.environment profile', () async {
    final sentryOptions = SentryOptions(dsn: fakeDsn)
      ..platformChecker = FakePlatformChecker.profileMode();
    await Sentry.init((options) {
      options.dsn = fakeDsn;
      expect(options.environment, 'profile');
    }, options: sentryOptions);
  });

  test('options.environment production (defaultEnvironment)', () async {
    final sentryOptions = SentryOptions(dsn: fakeDsn)
      ..platformChecker = FakePlatformChecker.releaseMode();
    await Sentry.init((options) {
      options.dsn = fakeDsn;
      expect(options.environment, defaultEnvironment);
    }, options: sentryOptions);
  });
}
