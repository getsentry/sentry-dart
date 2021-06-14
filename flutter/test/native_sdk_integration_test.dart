import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'mocks.dart';
import 'sentry_flutter_options_test.dart';

void main() {
  group('$NativeSdkIntegration', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    test('test default values', () async {
      final channel = const MethodChannel('initNativeSdk');

      String? methodName;
      dynamic arguments;
      channel.setMockMethodCallHandler((call) async {
        methodName = call.method;
        arguments = call.arguments;
      });
      var sut = Fixture().getSut(channel);

      await sut.call(HubAdapter(), createOptions());

      channel.setMethodCallHandler(null);

      expect(methodName, 'initNativeSdk');
      expect(arguments, <String, dynamic>{
        'dsn': fakeDsn,
        'debug': true,
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
          {'name': 'pub:sentry', 'version': '5.1.1'}
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
      final channel = const MethodChannel('initNativeSdk');

      String? methodName;
      dynamic arguments;
      channel.setMockMethodCallHandler((call) async {
        methodName = call.method;
        arguments = call.arguments;
      });
      var sut = Fixture().getSut(channel);

      final options = createOptions()
        ..debug = false
        ..environment = 'foo'
        ..release = 'foo@bar+1'
        ..enableAutoSessionTracking = false
        ..enableNativeCrashHandling = false
        ..attachStacktrace = false
        ..attachThreads = true
        ..autoSessionTrackingInterval = Duration(minutes: 4)
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
          {'name': 'pub:sentry', 'version': '5.1.1'},
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
      final channel = const MethodChannel('initNativeSdk');
      channel.setMockMethodCallHandler((call) async {});
      var sut = Fixture().getSut(channel);

      final options = createOptions();
      await sut.call(HubAdapter(), options);

      expect(options.sdk.integrations, ['nativeSdkIntegration']);

      channel.setMethodCallHandler(null);
    });

    test('integration is not added in case of an exception', () async {
      final channel = const MethodChannel('initNativeSdk');
      channel.setMockMethodCallHandler((call) async {
        throw Exception('foo');
      });
      var sut = Fixture().getSut(channel);

      final options = createOptions();
      await sut.call(HubAdapter(), options);

      expect(options.sdk.integrations, []);

      channel.setMethodCallHandler(null);
    });
  });
}

SentryFlutterOptions createOptions() {
  final mockPlatformChecker = MockPlatformChecker(true);
  return SentryFlutterOptions(dsn: fakeDsn, checker: mockPlatformChecker);
}

class Fixture {
  NativeSdkIntegration getSut(MethodChannel channel) {
    return NativeSdkIntegration(channel);
  }
}
