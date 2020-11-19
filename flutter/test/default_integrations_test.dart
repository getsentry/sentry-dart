import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/default_integrations.dart';

import 'mocks.dart';

void main() {
  const MethodChannel _channel = MethodChannel('sentry_flutter');

  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    _channel.setMockMethodCallHandler(null);
  });

  test('FlutterError capture errors', () async {
    final hub = MockHub();
    final options = SentryOptions();

    flutterErrorIntegration(hub, options);

    final throwable = StateError('error');
    final details = FlutterErrorDetails(exception: throwable);
    FlutterError.reportError(details);

    final event = verify(
      await hub.captureEvent(captureAny),
    ).captured.first as SentryEvent;

    expect(SentryLevel.fatal, event.level);

    final throwableMechanism = event.throwable as ThrowableMechanism;
    expect('FlutterError', throwableMechanism.mechanism.type);
    expect(true, throwableMechanism.mechanism.handled);
    expect(throwable, throwableMechanism.throwable);
  });

  test('FlutterError calls default error', () async {
    final hub = MockHub();
    final options = SentryOptions();

    var called = false;
    final defaultError = (FlutterErrorDetails errorDetails) async {
      called = true;
    };
    FlutterError.onError = defaultError;

    flutterErrorIntegration(hub, options);

    final throwable = StateError('error');
    final details = FlutterErrorDetails(exception: throwable);
    FlutterError.reportError(details);

    verify(
      await hub.captureEvent(captureAny),
    ).captured.first as SentryEvent;

    expect(true, called);
  });

  test('FlutterError adds integration', () async {
    final hub = MockHub();
    final options = SentryOptions();

    flutterErrorIntegration(hub, options);

    expect(true, options.sdk.integrations.contains('flutterErrorIntegration'));
  });

  test('Isolate error adds integration', () async {
    // we could not find a way to trigger an error to the current Isolate
    // and unit test its error handling.

    final hub = MockHub();
    final options = SentryOptions();

    isolateErrorIntegration(hub, options);

    expect(true, options.sdk.integrations.contains('isolateErrorIntegration'));
  });

  test('Run zoned guarded adds integration', () async {
    final hub = MockHub();
    final options = SentryOptions();

    isolateErrorIntegration(hub, options);

    void callback() {}
    final integration = runZonedGuardedIntegration(callback);

    integration(hub, options);

    expect(
        true, options.sdk.integrations.contains('runZonedGuardedIntegration'));
  });

  test('Run zoned guarded calls callback', () async {
    final hub = MockHub();
    final options = SentryOptions();

    isolateErrorIntegration(hub, options);

    var called = false;
    void callback() {
      called = true;
    }

    final integration = runZonedGuardedIntegration(callback);

    integration(hub, options);

    expect(true, called);
  });

  test('Run zoned guarded calls catches error', () async {
    final hub = MockHub();
    final options = SentryOptions();

    final throwable = StateError('error');
    void callback() {
      throw throwable;
    }

    final integration = runZonedGuardedIntegration(callback);
    integration(hub, options);

    final event = verify(
      await hub.captureEvent(captureAny,
          stackTrace: captureAnyNamed('stackTrace')),
    ).captured.first as SentryEvent;

    expect(SentryLevel.fatal, event.level);

    final throwableMechanism = event.throwable as ThrowableMechanism;
    expect('runZonedGuarded', throwableMechanism.mechanism.type);
    expect(true, throwableMechanism.mechanism.handled);
    expect(throwable, throwableMechanism.throwable);
  });

  test('nativeSdkIntegration adds integration', () async {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

    final hub = MockHub();
    final options = SentryOptions();

    final integration = nativeSdkIntegration(options, _channel);

    await integration(hub, options);

    expect(true, options.sdk.integrations.contains('nativeSdkIntegration'));
  });

  test('nativeSdkIntegration do not throw', () async {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {
      throw null;
    });

    final hub = MockHub();
    final options = SentryOptions();

    final integration = nativeSdkIntegration(options, _channel);

    await integration(hub, options);

    expect(false, options.sdk.integrations.contains('nativeSdkIntegration'));
  });
}
