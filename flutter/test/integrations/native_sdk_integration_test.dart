@TestOn('vm')

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/native_sdk_integration.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  const _channel = MethodChannel('sentry_flutter');

  TestWidgetsFlutterBinding.ensureInitialized();

  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  tearDown(() {
    // ignore: deprecated_member_use
    _channel.setMockMethodCallHandler(null);
  });

  test('nativeSdkIntegration adds integration', () async {
    // ignore: deprecated_member_use
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

    final integration = NativeSdkIntegration(_channel);

    await integration(fixture.hub, fixture.options);

    expect(fixture.options.sdk.integrations.contains('nativeSdkIntegration'),
        true);
  });

  test('nativeSdkIntegration do not throw', () async {
    // ignore: deprecated_member_use
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {
      throw Exception();
    });

    final integration = NativeSdkIntegration(_channel);

    await integration(fixture.hub, fixture.options);

    expect(fixture.options.sdk.integrations.contains('nativeSdkIntegration'),
        false);
  });

  test('nativeSdkIntegration closes native SDK', () async {
    var closeCalled = false;
    // ignore: deprecated_member_use
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {
      expect(methodCall.method, 'closeNativeSdk');
      closeCalled = true;
    });

    final integration = NativeSdkIntegration(_channel);

    await integration.close();

    expect(closeCalled, true);
  });

  test('nativeSdkIntegration does not call native sdk when auto init disabled',
      () async {
    var methodChannelCalled = false;
    // ignore: deprecated_member_use
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {
      methodChannelCalled = true;
    });
    fixture.options.autoInitializeNativeSdk = false;

    final integration = NativeSdkIntegration(_channel);

    await integration.call(fixture.hub, fixture.options);

    expect(methodChannelCalled, false);
  });

  test('nativeSdkIntegration does not close native when auto init disabled',
      () async {
    var methodChannelCalled = false;
    // ignore: deprecated_member_use
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {
      methodChannelCalled = true;
    });
    fixture.options.autoInitializeNativeSdk = false;

    final integration = NativeSdkIntegration(_channel);

    await integration(fixture.hub, fixture.options);
    await integration.close();

    expect(methodChannelCalled, false);
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions(dsn: fakeDsn);
}
