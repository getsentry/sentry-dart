import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/binding_utils.dart';

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
    FlutterErrorDetails? optionalDetails,
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
      context: DiagnosticsNode.message('while handling a gesture'),
      library: 'sentry',
      informationCollector: () => [DiagnosticsNode.message('foo bar')],
    );
    FlutterError.reportError(optionalDetails ?? details);
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
    expect(throwableMechanism.mechanism.data['hint'],
        'See "flutter_error_details" down below for more information');
    expect(throwableMechanism.throwable, exception);

    expect(event.contexts['flutter_error_details']['library'], 'sentry');
    expect(event.contexts['flutter_error_details']['context'],
        'thrown while handling a gesture');
    expect(event.contexts['flutter_error_details']['information'], 'foo bar');
  });

  test('FlutterError capture errors with long FlutterErrorDetails.information',
      () async {
    final details = FlutterErrorDetails(
      exception: StateError('error'),
      silent: false,
      context: DiagnosticsNode.message('while handling a gesture'),
      library: 'sentry',
      informationCollector: () => [
        DiagnosticsNode.message('foo bar'),
        DiagnosticsNode.message('Hello World!')
      ],
    );

    // exception is ignored in this case
    _reportError(exception: StateError('error'), optionalDetails: details);

    final event = verify(
      await fixture.hub.captureEvent(captureAny),
    ).captured.first as SentryEvent;

    expect(event.level, SentryLevel.fatal);

    final throwableMechanism = event.throwableMechanism as ThrowableMechanism;
    expect(throwableMechanism.mechanism.type, 'FlutterError');
    expect(throwableMechanism.mechanism.handled, true);
    expect(throwableMechanism.mechanism.data['hint'],
        'See "flutter_error_details" down below for more information');

    expect(event.contexts['flutter_error_details']['library'], 'sentry');
    expect(event.contexts['flutter_error_details']['context'],
        'thrown while handling a gesture');
    expect(event.contexts['flutter_error_details']['information'],
        'foo bar\nHello World!');
  });

  test('FlutterError capture errors with no FlutterErrorDetails', () async {
    final details = FlutterErrorDetails(
        exception: StateError('error'), silent: false, library: null);

    // exception is ignored in this case
    _reportError(exception: StateError('error'), optionalDetails: details);

    final event = verify(
      await fixture.hub.captureEvent(captureAny),
    ).captured.first as SentryEvent;

    expect(event.level, SentryLevel.fatal);

    final throwableMechanism = event.throwableMechanism as ThrowableMechanism;
    expect(throwableMechanism.mechanism.type, 'FlutterError');
    expect(throwableMechanism.mechanism.handled, true);
    expect(throwableMechanism.mechanism.data['hint'], isNull);

    expect(event.contexts['flutter_error_details'], isNull);
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
    await integrationA.close();

    final integrationB = FlutterErrorIntegration();
    integrationB.call(fixture.hub, fixture.options);

    FlutterError.reportError(details);

    verify(await fixture.hub.captureEvent(captureAny)).called(1);

    expect(numberOfDefaultCalls, 1);
  });

  test('FlutterErrorIntegration close restored default onError', () async {
    final defaultOnError = (FlutterErrorDetails errorDetails) async {};
    FlutterError.onError = defaultOnError;

    final integration = FlutterErrorIntegration();
    integration.call(fixture.hub, fixture.options);
    expect(false, defaultOnError == FlutterError.onError);

    await integration.close();
    expect(FlutterError.onError, defaultOnError);
  });

  test('FlutterErrorIntegration default not restored if set after integration',
      () async {
    final defaultOnError = (FlutterErrorDetails errorDetails) async {};
    FlutterError.onError = defaultOnError;

    final integration = FlutterErrorIntegration();
    integration.call(fixture.hub, fixture.options);
    expect(defaultOnError == FlutterError.onError, false);

    final afterIntegrationOnError = (FlutterErrorDetails errorDetails) async {};
    FlutterError.onError = afterIntegrationOnError;

    await integration.close();
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

    final integration = InitNativeSdkIntegration(_channel);

    await integration(fixture.hub, fixture.options);

    expect(
        fixture.options.sdk.integrations.contains('initNativeSdkIntegration'),
        true);
  });

  test('nativeSdkIntegration do not throw', () async {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {
      throw Exception();
    });

    final integration = InitNativeSdkIntegration(_channel);

    await integration(fixture.hub, fixture.options);

    expect(fixture.options.sdk.integrations.contains('nativeSdkIntegration'),
        false);
  });

  test('nativeSdkIntegration closes native SDK', () async {
    var closeCalled = false;
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {
      expect(methodCall.method, 'closeNativeSdk');
      closeCalled = true;
    });

    final integration = InitNativeSdkIntegration(_channel);

    await integration.close();

    expect(closeCalled, true);
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
      return BindingUtils.getWidgetsBindingInstance()!;
    };
    final integration = WidgetsFlutterBindingIntegration(ensureInitialized);
    await integration(fixture.hub, fixture.options);

    expect(called, true);
  });

  group('$LoadReleaseIntegration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('does not overwrite options', () async {
      fixture.options.release = '1.0.0';
      fixture.options.dist = 'dist';

      await fixture.getIntegration().call(MockHub(), fixture.options);

      expect(fixture.options.release, '1.0.0');
      expect(fixture.options.dist, 'dist');
    });

    test('sets release and dist if not set on options', () async {
      await fixture.getIntegration().call(MockHub(), fixture.options);

      expect(fixture.options.release, 'foo.bar@1.2.3+789');
      expect(fixture.options.dist, '789');
    });

    test('sets app name as in release if packagename is empty', () async {
      final loader = () {
        return Future.value(PackageInfo(
          appName: 'sentry_flutter',
          packageName: '',
          version: '1.2.3',
          buildNumber: '789',
          buildSignature: '',
        ));
      };
      await fixture
          .getIntegration(loader: loader)
          .call(MockHub(), fixture.options);

      expect(fixture.options.release, 'sentry_flutter@1.2.3+789');
      expect(fixture.options.dist, '789');
    });

    test('release name does not contain invalid chars defined by Sentry',
        () async {
      final loader = () {
        return Future.value(PackageInfo(
          appName: '\\/sentry\tflutter \r\nfoo\nbar\r',
          packageName: '',
          version: '1.2.3',
          buildNumber: '789',
          buildSignature: '',
        ));
      };
      await fixture
          .getIntegration(loader: loader)
          .call(MockHub(), fixture.options);

      expect(fixture.options.release, '__sentry_flutter _foo_bar_@1.2.3+789');
      expect(fixture.options.dist, '789');
    });

    /// See the following issues:
    /// - https://github.com/getsentry/sentry-dart/issues/410
    /// - https://github.com/fluttercommunity/plus_plugins/issues/182
    test('does not send Unicode NULL \\u0000 character in app name or version',
        () async {
      final loader = () {
        return Future.value(PackageInfo(
          // As per
          // https://api.dart.dev/stable/2.12.4/dart-core/String-class.html
          // this is how \u0000 is added to a string in dart
          appName: 'sentry_flutter_example\u{0000}',
          packageName: '',
          version: '1.0.0\u{0000}',
          buildNumber: '',
          buildSignature: '',
        ));
      };
      await fixture
          .getIntegration(loader: loader)
          .call(MockHub(), fixture.options);

      expect(fixture.options.release, 'sentry_flutter_example@1.0.0');
    });

    /// See the following issues:
    /// - https://github.com/getsentry/sentry-dart/issues/410
    /// - https://github.com/fluttercommunity/plus_plugins/issues/182
    test(
        'does not send Unicode NULL \\u0000 character in package name or build number',
        () async {
      final loader = () {
        return Future.value(PackageInfo(
          // As per
          // https://api.dart.dev/stable/2.12.4/dart-core/String-class.html
          // this is how \u0000 is added to a string in dart
          appName: '',
          packageName: 'sentry_flutter_example\u{0000}',
          version: '',
          buildNumber: '123\u{0000}',
          buildSignature: '',
        ));
      };
      await fixture
          .getIntegration(loader: loader)
          .call(MockHub(), fixture.options);

      expect(fixture.options.release, 'sentry_flutter_example+123');
    });

    test('dist is null if build number is an empty string', () async {
      final loader = () {
        return Future.value(PackageInfo(
          appName: 'sentry_flutter_example',
          packageName: 'a.b.c',
          version: '1.0.0',
          buildNumber: '',
          buildSignature: '',
        ));
      };
      await fixture
          .getIntegration(loader: loader)
          .call(MockHub(), fixture.options);

      expect(fixture.options.dist, isNull);
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions(dsn: fakeDsn);

  LoadReleaseIntegration getIntegration({PackageLoader? loader}) {
    return LoadReleaseIntegration(loader ?? loadRelease);
  }

  Future<PackageInfo> loadRelease() {
    return Future.value(PackageInfo(
      appName: 'sentry_flutter',
      packageName: 'foo.bar',
      version: '1.2.3',
      buildNumber: '789',
      buildSignature: '',
    ));
  }
}
