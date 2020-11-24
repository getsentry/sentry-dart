import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'mocks.dart';

void main() {
  const MethodChannel _channel = MethodChannel('sentry_flutter');

  TestWidgetsFlutterBinding.ensureInitialized();

  Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  tearDown(() {
    _channel.setMockMethodCallHandler(null);
  });

  test('FlutterError capture errors', () async {
    // replace default error otherwise it fails on testing
    FlutterError.onError = (FlutterErrorDetails errorDetails) async {};

    flutterErrorIntegration(fixture.hub, fixture.options);

    final throwable = StateError('error');
    final details = FlutterErrorDetails(exception: throwable);
    FlutterError.reportError(details);

    final event = verify(
      await fixture.hub.captureEvent(captureAny),
    ).captured.first as SentryEvent;

    expect(SentryLevel.fatal, event.level);

    final throwableMechanism = event.throwable as ThrowableMechanism;
    expect('FlutterError', throwableMechanism.mechanism.type);
    expect(true, throwableMechanism.mechanism.handled);
    expect(throwable, throwableMechanism.throwable);
  });

  test('FlutterError calls default error', () async {
    var called = false;
    final defaultError = (FlutterErrorDetails errorDetails) async {
      called = true;
    };
    FlutterError.onError = defaultError;

    flutterErrorIntegration(fixture.hub, fixture.options);

    final throwable = StateError('error');
    final details = FlutterErrorDetails(exception: throwable);
    FlutterError.reportError(details);

    verify(
      await fixture.hub.captureEvent(captureAny),
    ).captured.first as SentryEvent;

    expect(true, called);
  });

  test('FlutterError adds integration', () async {
    flutterErrorIntegration(fixture.hub, fixture.options);

    expect(true,
        fixture.options.sdk.integrations.contains('flutterErrorIntegration'));
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

  test('nativeSdkIntegration adds integration', () async {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

    final integration = nativeSdkIntegration(fixture.options, _channel);

    await integration(fixture.hub, fixture.options);

    expect(true,
        fixture.options.sdk.integrations.contains('nativeSdkIntegration'));
  });

  test('nativeSdkIntegration do not throw', () async {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {
      throw null;
    });

    final integration = nativeSdkIntegration(fixture.options, _channel);

    await integration(fixture.hub, fixture.options);

    expect(false,
        fixture.options.sdk.integrations.contains('nativeSdkIntegration'));
  });

  test('loadContextsIntegration adds integration on ios', () async {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

    final integration = loadContextsIntegration(fixture.options, _channel);

    await integration(fixture.hub, fixture.options);

    expect(true,
        fixture.options.sdk.integrations.contains('loadContextsIntegration'));
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryOptions();
}
