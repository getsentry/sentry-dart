import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_hub.dart';

void main() {
  late Fixture fixture;

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

      expect(fixture.hub.captureEventCalls.length, 1);
      final event = fixture.hub.captureEventCalls.first.event;

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
      Future<void> callback() async {}
      final integration = RunZonedGuardedIntegration(callback);

      await integration(fixture.hub, fixture.options);

      expect(
          true,
          fixture.options.sdk.integrations
              .contains('runZonedGuardedIntegration'));
    },
    onPlatform: {
      'browser': Skip(),
    },
  );

  test('Run zoned guarded calls callback', () async {
    var called = false;
    Future<void> callback() async {
      called = true;
    }

    final integration = RunZonedGuardedIntegration(callback);

    await integration(fixture.hub, fixture.options);

    expect(true, called);
  }, onPlatform: {'browser': Skip()});

  test('Run zoned guarded calls catches integrations errors', () async {
    final throwable = StateError('error');
    Future<void> callback() async {
      throw throwable;
    }

    final integration = RunZonedGuardedIntegration(callback);

    await integration(fixture.hub, fixture.options);

    expect(fixture.hub.captureEventCalls.length, 1);
    final event = fixture.hub.captureEventCalls.first.event;

    expect(SentryLevel.fatal, event.level);

    final throwableMechanism = event.throwable as ThrowableMechanism;
    expect('runZonedGuarded', throwableMechanism.mechanism.type);
    expect(true, throwableMechanism.mechanism.handled);
    expect(throwable, throwableMechanism.throwable);
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryOptions(dsn: fakeDsn);
}
