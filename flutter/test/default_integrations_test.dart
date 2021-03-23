import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:package_info/package_info.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/sentry_flutter_options.dart';

import 'mocks.dart';
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

    when(fixture.hub.captureEvent(captureAny))
        .thenAnswer((_) => Future.value(SentryId.empty()));

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

    expect(event.level, SentryLevel.fatal);

    final throwableMechanism = event.throwableMechanism as ThrowableMechanism;
    expect(throwableMechanism.mechanism.type, 'FlutterError');
    expect(throwableMechanism.mechanism.handled, true);
    expect(throwableMechanism.throwable, exception);
  });

  test('FlutterError calls default error', () async {
    var called = false;
    final defaultError = (FlutterErrorDetails errorDetails) async {
      called = true;
    };

    _reportError(handler: defaultError);

    verify(await fixture.hub.captureEvent(captureAny));

    expect(called, true);
  });

  test('FlutterErrorIntegration captureEvent only called once', () async {
    var numberOfDefaultCalls = 0;
    final defaultError = (FlutterErrorDetails errorDetails) async {
      numberOfDefaultCalls++;
    };
    FlutterError.onError = defaultError;

    when(fixture.hub.captureEvent(captureAny))
        .thenAnswer((_) => Future.value(SentryId.empty()));

    final details = FlutterErrorDetails(exception: StateError('error'));

    final integrationA = FlutterErrorIntegration();
    integrationA.call(fixture.hub, fixture.options);
    integrationA.close();

    final integrationB = FlutterErrorIntegration();
    integrationB.call(fixture.hub, fixture.options);

    FlutterError.reportError(details);

    verify(await fixture.hub.captureEvent(captureAny)).called(1);

    expect(numberOfDefaultCalls, 1);
  });

  test('FlutterErrorIntegration close restored default onError', () {
    final defaultOnError = (FlutterErrorDetails errorDetails) async {};
    FlutterError.onError = defaultOnError;

    final integration = FlutterErrorIntegration();
    integration.call(fixture.hub, fixture.options);
    expect(false, defaultOnError == FlutterError.onError);

    integration.close();
    expect(FlutterError.onError, defaultOnError);
  });

  test('FlutterErrorIntegration default not restored if set after integration',
      () {
    final defaultOnError = (FlutterErrorDetails errorDetails) async {};
    FlutterError.onError = defaultOnError;

    final integration = FlutterErrorIntegration();
    integration.call(fixture.hub, fixture.options);
    expect(defaultOnError == FlutterError.onError, false);

    final afterIntegrationOnError = (FlutterErrorDetails errorDetails) async {};
    FlutterError.onError = afterIntegrationOnError;

    integration.close();
    expect(FlutterError.onError, afterIntegrationOnError);
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

  test('FlutterError adds integration', () {
    FlutterErrorIntegration()(fixture.hub, fixture.options);

    expect(fixture.options.sdk.integrations.contains('flutterErrorIntegration'),
        true);
  });

  test('nativeSdkIntegration adds integration', () async {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

    final integration = NativeSdkIntegration(_channel);

    await integration(fixture.hub, fixture.options);

    expect(fixture.options.sdk.integrations.contains('nativeSdkIntegration'),
        true);
  });

  test('nativeSdkIntegration do not throw', () async {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {
      throw Exception();
    });

    final integration = NativeSdkIntegration(_channel);

    await integration(fixture.hub, fixture.options);

    expect(fixture.options.sdk.integrations.contains('nativeSdkIntegration'),
        false);
  });

  test('loadContextsIntegration adds integration', () async {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

    final integration = LoadContextsIntegration(_channel);

    await integration(fixture.hub, fixture.options);

    expect(fixture.options.sdk.integrations.contains('loadContextsIntegration'),
        true);
  });

  test('WidgetsFlutterBindingIntegration adds integration', () async {
    final integration = WidgetsFlutterBindingIntegration();
    await integration(fixture.hub, fixture.options);

    expect(
        fixture.options.sdk.integrations
            .contains('widgetsFlutterBindingIntegration'),
        true);
  });

  test('WidgetsFlutterBindingIntegration calls ensureInitialized', () async {
    var called = false;
    var ensureInitialized = () {
      called = true;
      return WidgetsBinding.instance!;
    };
    final integration = WidgetsFlutterBindingIntegration(ensureInitialized);
    await integration(fixture.hub, fixture.options);

    expect(called, true);
  });

  group('$LoadReleaseIntegration', () {
    Future<PackageInfo> loadRelease() {
      return Future.value(PackageInfo(
        appName: 'sentry_flutter',
        packageName: 'foo.bar',
        version: '1.2.3',
        buildNumber: '789',
      ));
    }

    test('does not overwrite options', () async {
      final options = SentryFlutterOptions(dsn: fakeDsn);
      options.release = '1.0.0';
      options.dist = 'dist';

      final integration = LoadReleaseIntegration(loadRelease);
      await integration.call(MockHub(), options);

      expect(options.release, '1.0.0');
      expect(options.dist, 'dist');
    });

    test('sets release and dist if not set on options', () async {
      final options = SentryFlutterOptions(dsn: fakeDsn);

      final integration = LoadReleaseIntegration(loadRelease);
      await integration.call(MockHub(), options);

      expect(options.release, 'foo.bar@1.2.3+789');
      expect(options.dist, '789');
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions();
}
