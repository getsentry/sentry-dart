import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/version.dart';

import 'mocks.dart';

void main() {
  group('$NativeSdkIntegration', () {
    late Fixture fixture;
    setUp(() {
      fixture = Fixture();
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    test('test default values', () async {
      String? methodName;
      dynamic arguments;
      final channel = createChannelWithCallback((call) async {
        methodName = call.method;
        arguments = call.arguments;
      });
      var sut = fixture.getSut(channel);

      await sut.call(HubAdapter(), createOptions());

      channel.setMethodCallHandler(null);

      expect(methodName, 'initNativeSdk');
      expect(arguments, <String, dynamic>{
        'dsn': fakeDsn,
        'debug': false,
        'environment': null,
        'release': null,
        'enableAutoSessionTracking': true,
        'enableNativeCrashHandling': true,
        'attachStacktrace': true,
        'attachThreads': false,
        'autoSessionTrackingIntervalMillis': 30000,
        'dist': null,
        'integrations': [],
        'packages': [
          {'name': 'pub:sentry', 'version': sdkVersion}
        ],
        'diagnosticLevel': 'debug',
        'maxBreadcrumbs': 100,
        'anrEnabled': false,
        'anrTimeoutIntervalMillis': 5000,
        'enableAutoNativeBreadcrumbs': true,
        'maxCacheItems': 30,
        'sendDefaultPii': false,
        'enableOutOfMemoryTracking': true,
      });
    });

    test('test custom values', () async {
      String? methodName;
      dynamic arguments;
      final channel = createChannelWithCallback((call) async {
        methodName = call.method;
        arguments = call.arguments;
      });
      var sut = fixture.getSut(channel);

      final options = createOptions()
        ..debug = false
        ..environment = 'foo'
        ..release = 'foo@bar+1'
        ..enableAutoSessionTracking = false
        ..enableNativeCrashHandling = false
        ..attachStacktrace = false
        ..attachThreads = true
        ..autoSessionTrackingInterval = Duration(milliseconds: 240000)
        ..dist = 'distfoo'
        ..diagnosticLevel = SentryLevel.error
        ..maxBreadcrumbs = 0
        ..anrEnabled = false
        ..anrTimeoutInterval = Duration.zero
        ..enableAutoNativeBreadcrumbs = false
        ..maxCacheItems = 0
        ..sendDefaultPii = true
        ..enableOutOfMemoryTracking = false;

      options.sdk.addIntegration('foo');
      options.sdk.addPackage('bar', '1');

      await sut.call(HubAdapter(), options);

      channel.setMethodCallHandler(null);

      expect(methodName, 'initNativeSdk');
      expect(arguments, <String, dynamic>{
        'dsn': fakeDsn,
        'debug': false,
        'environment': 'foo',
        'release': 'foo@bar+1',
        'enableAutoSessionTracking': false,
        'enableNativeCrashHandling': false,
        'attachStacktrace': false,
        'attachThreads': true,
        'autoSessionTrackingIntervalMillis': 240000,
        'dist': 'distfoo',
        'integrations': ['foo'],
        'packages': [
          {'name': 'pub:sentry', 'version': sdkVersion},
          {'name': 'bar', 'version': '1'},
        ],
        'diagnosticLevel': 'error',
        'maxBreadcrumbs': 0,
        'anrEnabled': false,
        'anrTimeoutIntervalMillis': 0,
        'enableAutoNativeBreadcrumbs': false,
        'maxCacheItems': 0,
        'sendDefaultPii': true,
        'enableOutOfMemoryTracking': false,
      });
    });

    test('adds integration', () async {
      final channel = createChannelWithCallback((call) async {});
      var sut = fixture.getSut(channel);

      final options = createOptions();
      await sut.call(HubAdapter(), options);

      expect(options.sdk.integrations, ['nativeSdkIntegration']);

      channel.setMethodCallHandler(null);
    });

    test('integration is not added in case of an exception', () async {
      final channel = createChannelWithCallback((call) async {
        throw Exception('foo');
      });
      var sut = fixture.getSut(channel);

      final options = createOptions();
      await sut.call(NoOpHub(), options);

      expect(options.sdk.integrations, []);

      channel.setMethodCallHandler(null);
    });
  });
}

MethodChannel createChannelWithCallback(
  Future<dynamic>? Function(MethodCall call)? handler,
) {
  final channel = const MethodChannel('initNativeSdk');
  channel.setMockMethodCallHandler(handler);
  return channel;
}

SentryFlutterOptions createOptions() {
  final mockPlatformChecker = MockPlatformChecker(hasNativeIntegration: true);
  return SentryFlutterOptions(dsn: fakeDsn, checker: mockPlatformChecker);
}

class Fixture {
  NativeSdkIntegration getSut(MethodChannel channel) {
    return NativeSdkIntegration(channel);
  }
}
