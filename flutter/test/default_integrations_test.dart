import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/sentry_flutter_options.dart';

import 'mocks.mocks.dart';

void main() {
  const _channel = MethodChannel('sentry_flutter');

  TestWidgetsFlutterBinding.ensureInitialized();

  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  tearDown(() {
    _channel.setMockMethodCallHandler(null);
  });

  void _reportError({
    bool silent = false,
    FlutterExceptionHandler? handler,
    dynamic exception,
  }) {
    // replace default error otherwise it fails on testing
    FlutterError.onError =
        handler ?? (FlutterErrorDetails errorDetails) async {};

    when(fixture.hub.captureEvent(captureAny)).thenAnswer((_) => Future.value(SentryId.empty()));

    FlutterErrorIntegration()(fixture.hub, fixture.options);

    final throwable = exception ?? StateError('error');
    final details = FlutterErrorDetails(
      exception: throwable,
      silent: silent,
    );
    FlutterError.reportError(details);
  }

  test('FlutterError capture errors', () async {
    final exception = StateError('error');
    _reportError(exception: exception);

    final event = verify(
      await fixture.hub.captureEvent(captureAny),
    ).captured.first as SentryEvent;

    expect(SentryLevel.fatal, event.level);

    final throwableMechanism = event.throwableMechanism as ThrowableMechanism;
    expect('FlutterError', throwableMechanism.mechanism.type);
    expect(true, throwableMechanism.mechanism.handled);
    expect(exception, throwableMechanism.throwable);
  });

  test('FlutterError calls default error', () async {
    var called = false;
    final defaultError = (FlutterErrorDetails errorDetails) async {
      called = true;
    };

    _reportError(handler: defaultError);

    verify(await fixture.hub.captureEvent(captureAny));

    expect(true, called);
  });

  test('FlutterError do not capture if silent error', () async {
    _reportError(silent: true);

    verifyNever(await fixture.hub.captureEvent(captureAny));
  });

  test('FlutterError captures if silent error but reportSilentFlutterErrors',
      () async {
    fixture.options.reportSilentFlutterErrors = true;
    _reportError(silent: true);

    verify(await fixture.hub.captureEvent(captureAny));
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
      throw Exception();
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

  test('WidgetsFlutterBindingIntegration adds integration', () async {
    final integration = WidgetsFlutterBindingIntegration();
    await integration(fixture.hub, fixture.options);

    expect(
        true,
        fixture.options.sdk.integrations
            .contains('widgetsFlutterBindingIntegration'));
  });

  test('WidgetsFlutterBindingIntegration calls ensureInitialized', () async {
    var called = false;
    var ensureInitialized = () {
      called = true;
      return WidgetsBinding.instance;
    };
    final integration = WidgetsFlutterBindingIntegration(ensureInitialized);
    await integration(fixture.hub, fixture.options);

    expect(true, called);
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions();
}
