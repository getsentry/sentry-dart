@TestOn('vm')

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/native_sdk_integration.dart';
import 'package:sentry_flutter/src/version.dart';

import '../mocks.dart';

void main() {
  group(NativeSdkIntegration, () {
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
        'integrations': <String>[],
        'packages': [
          {'name': 'pub:sentry_flutter', 'version': sdkVersion}
        ],
        'diagnosticLevel': 'debug',
        'maxBreadcrumbs': 100,
        'anrEnabled': false,
        'anrTimeoutIntervalMillis': 5000,
        'enableAutoNativeBreadcrumbs': true,
        'maxCacheItems': 30,
        'sendDefaultPii': false,
        'enableWatchdogTerminationsTracking': true,
        'enableNdkScopeSync': false,
        'enableAutoPerformanceTracing': true,
        'sendClientReports': true,
        'sdk': {
          'name': 'sentry.dart.flutter',
          'version': sdkVersion,
        },
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
        ..anrTimeoutInterval = Duration(seconds: 1)
        ..enableAutoNativeBreadcrumbs = false
        ..maxCacheItems = 0
        ..sendDefaultPii = true
        ..enableWatchdogTerminationsTracking = false
        ..enableNdkScopeSync = true
        ..enableAutoPerformanceTracing = false
        ..sendClientReports = false;

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
          {'name': 'pub:sentry_flutter', 'version': sdkVersion},
          {'name': 'bar', 'version': '1'},
        ],
        'diagnosticLevel': 'error',
        'maxBreadcrumbs': 0,
        'anrEnabled': false,
        'anrTimeoutIntervalMillis': 1000,
        'enableAutoNativeBreadcrumbs': false,
        'maxCacheItems': 0,
        'sendDefaultPii': true,
        'enableWatchdogTerminationsTracking': false,
        'enableNdkScopeSync': true,
        'enableAutoPerformanceTracing': false,
        'sendClientReports': false,
        'sdk': {
          'name': 'sentry.dart.flutter',
          'version': sdkVersion,
        },
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

      expect(options.sdk.integrations, <String>[]);

      channel.setMethodCallHandler(null);
    });
  });
}

MethodChannel createChannelWithCallback(
  Future<dynamic>? Function(MethodCall call)? handler,
) {
  final channel = MethodChannel('initNativeSdk');
  channel.setMockMethodCallHandler(handler);
  return channel;
}

SentryFlutterOptions createOptions() {
  final mockPlatformChecker = MockPlatformChecker(hasNativeIntegration: true);
  final options = SentryFlutterOptions(
    dsn: fakeDsn,
    checker: mockPlatformChecker,
  );
  options.sdk = SdkVersion(
    name: sdkName,
    version: sdkVersion,
  );
  options.sdk.addPackage('pub:sentry_flutter', sdkVersion);
  return options;
}

class Fixture {
  NativeSdkIntegration getSut(MethodChannel channel) {
    return NativeSdkIntegration(channel);
  }
}
