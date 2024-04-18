import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/event_processor/deduplication_event_processor.dart';
import 'package:test/test.dart';

import 'fake_platform_checker.dart';
import 'mocks.dart';
import 'mocks/mock_integration.dart';
import 'mocks/mock_sentry_client.dart';

AppRunner appRunner = () {};

void main() {
  group('Sentry capture methods', () {
    var client = MockSentryClient();

    var anException = Exception();

    setUp(() async {
      final options = SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
      await Sentry.init(
        options: options,
        (options) {
          options.dsn = fakeDsn;
          options.tracesSampleRate = 1.0;
        },
      );
      anException = Exception('anException');

      client = MockSentryClient();
      Sentry.bindClient(client);
    });

    tearDown(() async {
      await Sentry.close();
    });

    test('should capture the event', () async {
      await Sentry.captureEvent(fakeEvent);

      expect(client.captureEventCalls.length, 1);
      expect(client.captureEventCalls.first.event, fakeEvent);
      expect(client.captureEventCalls.first.scope, isNotNull);
    });

    test('should capture the event withScope', () async {
      await Sentry.captureEvent(
        fakeEvent,
        withScope: (scope) {
          scope.setUser(SentryUser(id: 'foo bar'));
        },
      );

      expect(client.captureEventCalls.length, 1);
      expect(client.captureEventCalls.first.event, fakeEvent);
      expect(client.captureEventCalls.first.scope?.user?.id, 'foo bar');
    });

    test('should not capture a null exception', () async {
      await Sentry.captureException(null);
      expect(client.captureEventCalls.length, 0);
    });

    test('should capture the exception', () async {
      await Sentry.captureException(anException);
      expect(client.captureEventCalls.length, 1);
      expect(client.captureEventCalls.first.event.throwable, anException);
      expect(client.captureEventCalls.first.stackTrace, isNull);
      expect(client.captureEventCalls.first.scope, isNotNull);
    });

    test('should capture exception withScope', () async {
      await Sentry.captureException(anException, withScope: (scope) {
        scope.setUser(SentryUser(id: 'foo bar'));
      });
      expect(client.captureEventCalls.length, 1);
      expect(client.captureEventCalls.first.event.throwable, anException);
      expect(client.captureEventCalls.first.scope?.user?.id, 'foo bar');
    });

    test('should capture message', () async {
      await Sentry.captureMessage(
        fakeMessage.formatted,
        level: SentryLevel.warning,
      );

      expect(client.captureMessageCalls.length, 1);
      expect(client.captureMessageCalls.first.formatted, fakeMessage.formatted);
      expect(client.captureMessageCalls.first.level, SentryLevel.warning);
    });

    test('should capture message withScope', () async {
      await Sentry.captureMessage(
        fakeMessage.formatted,
        withScope: (scope) {
          scope.setUser(SentryUser(id: 'foo bar'));
        },
      );

      expect(client.captureMessageCalls.length, 1);
      expect(client.captureMessageCalls.first.formatted, fakeMessage.formatted);
      expect(client.captureMessageCalls.first.scope?.user?.id, 'foo bar');
    });

    test('should start transaction with given values', () async {
      final tr = Sentry.startTransaction('name', 'op');
      await tr.finish();

      expect(client.captureTransactionCalls.length, 1);
    });

    test('should start transaction with context', () async {
      final tr = Sentry.startTransactionWithContext(
          SentryTransactionContext('name', 'operation'));
      await tr.finish();

      expect(client.captureTransactionCalls.length, 1);
    });

    test('should return span if bound to the scope', () async {
      final tr = Sentry.startTransaction('name', 'op', bindToScope: true);

      expect(Sentry.getSpan(), tr);
    });

    test('should not return span if not bound to the scope', () async {
      Sentry.startTransaction('name', 'op');

      expect(Sentry.getSpan(), isNull);
    });

    test('should provide metrics API', () async {
      expect(Sentry.metrics(), Sentry.currentHub.metricsApi);
    });
  });

  group('Sentry is enabled or disabled', () {
    setUp(() async {
      await Sentry.close();
    });

    test('null DSN', () async {
      final options = SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
      expect(
        () async => await Sentry.init(
          options: options,
          (options) => options.dsn = null,
        ),
        throwsArgumentError,
      );
      expect(Sentry.isEnabled, false);
    });

    test('appRunner should be optional', () async {
      expect(Sentry.isEnabled, false);
      final options = SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
      await Sentry.init(
        options: options,
        (options) => options.dsn = fakeDsn,
      );
      expect(Sentry.isEnabled, true);
    });

    test('empty DSN', () async {
      final options = SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
      await Sentry.init(
        options: options,
        (options) => options.dsn = '',
      );
      expect(Sentry.isEnabled, false);
    });

    test('empty DSN disables the SDK but runs the integrations', () async {
      final integration = MockIntegration();

      final options = SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
      await Sentry.init(
        options: options,
        (options) {
          options.dsn = '';
          options.addIntegration(integration);
        },
      );

      expect(integration.callCalls, 1);
    });

    test('close disables the SDK', () async {
      final options = SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
      await Sentry.init(
        options: options,
        (options) => options.dsn = fakeDsn,
      );

      Sentry.bindClient(MockSentryClient());

      expect(Sentry.isEnabled, true);

      await Sentry.close();

      expect(Sentry.isEnabled, false);
    });
  });

  group('Sentry init', () {
    tearDown(() async {
      await Sentry.close();
    });

    test('should install integrations', () async {
      final integration = MockIntegration();

      final options = SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
      await Sentry.init(
        options: options,
        (options) {
          options.dsn = fakeDsn;
          options.addIntegration(integration);
        },
      );

      expect(integration.callCalls, 1);
    });

    test('should add default integrations', () async {
      late SentryOptions optionsReference;
      final options = SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
      await Sentry.init(
        options: options,
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
      final options = SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
      await Sentry.init(
        options: options,
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

      final options = SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
      await Sentry.init(
        options: options,
        (options) {
          options.dsn = fakeDsn;
          options.addIntegration(integration);
        },
      );

      await Sentry.close();

      expect(integration.callCalls, 1);
      expect(integration.closeCalls, 1);
    });

    test('$DeduplicationEventProcessor is added on init', () async {
      final options = SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
      await Sentry.init(
        options: options,
        (options) {
          options.dsn = fakeDsn;
          final count = options.eventProcessors
              .whereType<DeduplicationEventProcessor>()
              .length;
          expect(count, 1);
        },
      );
    });

    test('should complete when appRunner completes', () async {
      final completer = Completer();
      var completed = false;

      final options = SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
      final init = Sentry.init(
        options: options,
        (options) {
          options.dsn = fakeDsn;
        },
        appRunner: () => completer.future,
      ).whenComplete(() => completed = true);

      await Future(() {
        // We make the expectation only after all microtasks have completed,
        // that Sentry.init might have scheduled.
        expect(completed, false);
      });

      completer.complete();
      await init;

      expect(completed, true);
    });
  });

  test('should complete when appRunner is not called in runZonedGuarded',
      () async {
    final completer = Completer();
    var completed = false;

    final options = SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
    final init = Sentry.init(
      options: options,
      (options) {
        options.dsn = fakeDsn;
      },
      appRunner: () => completer.future,
      callAppRunnerInRunZonedGuarded: false,
    ).whenComplete(() => completed = true);

    await Future(() {
      // We make the expectation only after all microtasks have completed,
      // that Sentry.init might have scheduled.
      expect(completed, false);
    });

    completer.complete();
    await init;

    expect(completed, true);
  });

  test('options.environment debug', () async {
    final sentryOptions = SentryOptions(dsn: fakeDsn)
      ..automatedTestMode = true
      ..platformChecker = FakePlatformChecker.debugMode();

    final options = SentryOptions();
    options.automatedTestMode = true;
    await Sentry.init(
      (options) {
        options.dsn = fakeDsn;
        expect(options.environment, 'debug');
        expect(options.debug, false);
      },
      options: sentryOptions,
    );
  });

  test('options.environment profile', () async {
    final sentryOptions =
        SentryOptions(dsn: fakeDsn, checker: FakePlatformChecker.profileMode())
          ..automatedTestMode = true;

    await Sentry.init(
      (options) {
        options.dsn = fakeDsn;
        expect(options.environment, 'profile');
        expect(options.debug, false);
      },
      options: sentryOptions,
    );
  });

  test('options.environment production (defaultEnvironment)', () async {
    final sentryOptions =
        SentryOptions(dsn: fakeDsn, checker: FakePlatformChecker.releaseMode())
          ..automatedTestMode = true;
    await Sentry.init(
      (options) {
        options.dsn = fakeDsn;
        expect(options.environment, 'production');
        expect(options.debug, false);
      },
      options: sentryOptions,
    );
  });

  test('options.logger is set by setting the debug flag', () async {
    final sentryOptions =
        SentryOptions(dsn: fakeDsn, checker: FakePlatformChecker.debugMode())
          ..automatedTestMode = true;

    await Sentry.init(
      (options) {
        options.dsn = fakeDsn;
        options.debug = true;
        // ignore: deprecated_member_use_from_same_package
        expect(options.logger, isNot(noOpLogger));

        options.debug = false;
        // ignore: deprecated_member_use_from_same_package
        expect(options.logger, noOpLogger);
      },
      options: sentryOptions,
    );

    // ignore: deprecated_member_use_from_same_package
    expect(sentryOptions.logger, isNot(dartLogger));
  });

  group('Sentry init optionsConfiguration', () {
    final fixture = Fixture();

    test('throw is handled and logged', () async {
      final sentryOptions = SentryOptions(dsn: fakeDsn)
        ..automatedTestMode = false
        ..debug = true
        ..logger = fixture.mockLogger;

      final exception = Exception("Exception in options callback");
      await Sentry.init(
        (options) async {
          throw exception;
        },
        options: sentryOptions,
      );

      expect(fixture.loggedException, exception);
      expect(fixture.loggedLevel, SentryLevel.error);
    });
  });
}

class Fixture {
  bool logged = false;
  SentryLevel? loggedLevel;
  Object? loggedException;

  void mockLogger(
    SentryLevel level,
    String message, {
    String? logger,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    if (!logged) {
      logged = true; // Block multiple calls which override expected values.
      loggedLevel = level;
      loggedException = exception;
    }
  }
}
