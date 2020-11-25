import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('Isolate error adds integration', () async {
    isolateErrorIntegration(fixture.hub, fixture.options);

    expect(true,
        fixture.options.sdk.integrations.contains('isolateErrorIntegration'));
  });

  test('Isolate error capture errors', () async {
    final throwable = StateError('error');
    final stackTrace = StackTrace.current;
    final error = [throwable, stackTrace];

    // we could not find a way to trigger an error to the current Isolate
    // and unit test its error handling, so instead we exposed the method,
    // that handles and captures it.
    await handleIsolateError(fixture.hub, fixture.options, error);

    final event = verify(
      await fixture.hub
          .captureEvent(captureAny, stackTrace: captureAnyNamed('stackTrace')),
    ).captured.first as SentryEvent;

    expect(SentryLevel.fatal, event.level);

    final throwableMechanism = event.throwable as ThrowableMechanism;
    expect('isolateError', throwableMechanism.mechanism.type);
    expect(true, throwableMechanism.mechanism.handled);
    expect(throwable, throwableMechanism.throwable);
  });

  test('Run zoned guarded adds integration', () async {
    isolateErrorIntegration(fixture.hub, fixture.options);

    void callback() {}
    final integration = runZonedGuardedIntegration(callback);

    await integration(fixture.hub, fixture.options);

    expect(
        true,
        fixture.options.sdk.integrations
            .contains('runZonedGuardedIntegration'));
  });

  test('Run zoned guarded calls callback', () async {
    isolateErrorIntegration(fixture.hub, fixture.options);

    var called = false;
    void callback() {
      called = true;
    }

    final integration = runZonedGuardedIntegration(callback);

    await integration(fixture.hub, fixture.options);

    expect(true, called);
  });

  test('Run zoned guarded calls catches error', () async {
    final throwable = StateError('error');
    void callback() {
      throw throwable;
    }

    final integration = runZonedGuardedIntegration(callback);
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
