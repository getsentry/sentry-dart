import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'dart:async';

void main() {
  Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test(
    'Isolate error adds integration',
    () async {
      final integration = IsolateErrorIntegration();
      await integration(
        fixture.hub,
        fixture.options,
      );

      expect(
        true,
        fixture.options.sdk.integrations.contains('isolateErrorIntegration'),
      );
    },
    onPlatform: {
      'browser': Skip(),
    },
  );

  test(
    'Isolate error capture errors',
    () async {
      final throwable = StateError('error');
      final stackTrace = StackTrace.current;
      final error = [throwable, stackTrace];

      // we could not find a way to trigger an error to the current Isolate
      // and unit test its error handling, so instead we exposed the method,
      // that handles and captures it.
      await handleIsolateError(fixture.hub, fixture.options, error);

      final event = verify(
        await fixture.hub.captureEvent(
          captureAny,
          stackTrace: captureAnyNamed('stackTrace'),
        ),
      ).captured.first as SentryEvent;

      expect(SentryLevel.fatal, event.level);

      final throwableMechanism = event.throwable as ThrowableMechanism;
      expect('isolateError', throwableMechanism.mechanism.type);
      expect(true, throwableMechanism.mechanism.handled);
      expect(throwable, throwableMechanism.throwable);
    },
    onPlatform: {
      'browser': Skip(),
    },
  );

  test(
    'Run zoned guarded adds integrations',
    () async {
      void callback() {}
      final integration = RunZonedGuardedIntegration([CallbackIntegration(callback)]);

      await integration(fixture.hub, fixture.options);

      expect(
          true,
          fixture.options.sdk.integrations
              .contains('runZonedGuardedIntegration'));

      expect(
          true,
          fixture.options.sdk.integrations
              .contains('callbackIntegration'));
    },
    onPlatform: {
      'browser': Skip(),
    },
  );

  test('Run zoned guarded calls integrations', () async {
    var calledA = false;
    void callbackA() {
      calledA = true;
    }
    var calledB = false;
    void callbackB() {
      calledB = true;
    }

    final integration = RunZonedGuardedIntegration(
      [CallbackIntegration(callbackA), CallbackIntegration(callbackB)]
    );

    await integration(fixture.hub, fixture.options);

    expect(true, calledA);
    expect(true, calledB);
  }, onPlatform: {'browser': Skip()});

  test('Run zoned guarded calls catches integrations errors', () async {
    final throwable = StateError('error');
    void callback() {
      throw throwable;
    }

    final integration = RunZonedGuardedIntegration([CallbackIntegration(callback)]);
    await integration(fixture.hub, fixture.options);

    final event = verify(
      await fixture.hub
          .captureEvent(captureAny, stackTrace: captureAnyNamed('stackTrace')),
    ).captured.first as SentryEvent;

    expect(SentryLevel.fatal, event.level);

    final throwableMechanism = event.throwable as ThrowableMechanism;
    expect('runZonedGuarded', throwableMechanism.mechanism.type);
    expect(true, throwableMechanism.mechanism.handled);
    expect(throwable, throwableMechanism.throwable);
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryOptions();
}

class CallbackIntegration extends Integration {
  CallbackIntegration(this.callback);
  Function() callback;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) async {
    await callback();
    options.sdk.addIntegration('callbackIntegration');
  }
}
