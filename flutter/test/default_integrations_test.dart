import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'mocks.dart';

void main() {
  const _channel = MethodChannel('sentry_flutter');

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

    FlutterErrorIntegration()(fixture.hub, fixture.options);

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

    FlutterErrorIntegration()(fixture.hub, fixture.options);

    final throwable = StateError('error');
    final details = FlutterErrorDetails(exception: throwable);
    FlutterError.reportError(details);

    verify(
      await fixture.hub.captureEvent(captureAny),
    ).captured.first as SentryEvent;

    expect(true, called);
  });

  test('FlutterError adds integration', () async {
    FlutterErrorIntegration()(fixture.hub, fixture.options);

    expect(true,
        fixture.options.sdk.integrations.contains('flutterErrorIntegration'));
  });

  test('nativeSdkIntegration adds integration', () async {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

    final integration = NativeSdkIntegration(_channel);

    await integration(fixture.hub, fixture.options);

    expect(true,
        fixture.options.sdk.integrations.contains('nativeSdkIntegration'));
  });

  test('nativeSdkIntegration do not throw', () async {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {
      throw null;
    });

    final integration = NativeSdkIntegration(_channel);

    await integration(fixture.hub, fixture.options);

    expect(false,
        fixture.options.sdk.integrations.contains('nativeSdkIntegration'));
  });

  test('loadContextsIntegration adds integration', () async {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

    final integration = LoadContextsIntegration(_channel);

    await integration(fixture.hub, fixture.options);

    expect(true,
        fixture.options.sdk.integrations.contains('loadContextsIntegration'));
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryOptions();
}
