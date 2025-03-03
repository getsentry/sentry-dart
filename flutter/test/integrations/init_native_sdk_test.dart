@TestOn('vm')
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/sentry_native_channel.dart';
import 'package:sentry_flutter/src/version.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
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

    await sut.init(MockHub());

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
      'sdk': {
        'name': 'sentry.dart.flutter',
        'version': sdkVersion,
        'packages': [
          {'name': 'pub:sentry_flutter', 'version': sdkVersion}
        ]
      },
      'diagnosticLevel': 'debug',
      'maxBreadcrumbs': 100,
      'anrEnabled': false,
      'anrTimeoutIntervalMillis': 5000,
      'enableAutoNativeBreadcrumbs': true,
      'maxCacheItems': 30,
      'sendDefaultPii': false,
      'enableWatchdogTerminationTracking': true,
      'enableNdkScopeSync': true,
      'enableAutoPerformanceTracing': true,
      'sendClientReports': true,
      'proguardUuid': null,
      'maxAttachmentSize': 20 * 1024 * 1024,
      'recordHttpBreadcrumbs': true,
      'captureFailedRequests': true,
      'enableAppHangTracking': true,
      'connectionTimeoutMillis': 5000,
      'readTimeoutMillis': 5000,
      'appHangTimeoutIntervalMillis': 2000,
      'replay': <String, dynamic>{
        'quality': 'medium',
        'sessionSampleRate': null,
        'onErrorSampleRate': null,
        'tags': {
          'maskAllText': true,
          'maskAllImages': true,
          'maskAssetImages': false,
        }
      },
      'enableSpotlight': false,
      'spotlightUrl': null,
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

    fixture.options
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
      ..enableWatchdogTerminationTracking = false
      ..enableAutoPerformanceTracing = false
      ..sendClientReports = false
      ..enableNdkScopeSync = true
      ..proguardUuid = fakeProguardUuid
      ..maxAttachmentSize = 10
      ..recordHttpBreadcrumbs = false
      ..captureFailedRequests = false
      ..enableAppHangTracking = false
      ..connectionTimeout = Duration(milliseconds: 9001)
      ..readTimeout = Duration(milliseconds: 9002)
      ..appHangTimeoutInterval = Duration(milliseconds: 9003)
      ..proxy = SentryProxy(
        host: "localhost",
        port: 8080,
        type: SentryProxyType.http,
        user: 'admin',
        pass: '0000',
      )
      ..replay.quality = SentryReplayQuality.high
      ..replay.sessionSampleRate = 0.1
      ..replay.onErrorSampleRate = 0.2
      ..privacy.mask<Image>()
      ..spotlight =
          Spotlight(enabled: true, url: 'http://localhost:8969/stream');

    fixture.options.sdk.addIntegration('foo');
    fixture.options.sdk.addPackage('bar', '1');

    await sut.init(MockHub());

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
      'sdk': {
        'name': 'sentry.dart.flutter',
        'version': sdkVersion,
        'packages': [
          {'name': 'pub:sentry_flutter', 'version': sdkVersion},
          {'name': 'bar', 'version': '1'},
        ],
        'integrations': ['foo'],
      },
      'diagnosticLevel': 'error',
      'maxBreadcrumbs': 0,
      'anrEnabled': false,
      'anrTimeoutIntervalMillis': 1000,
      'enableAutoNativeBreadcrumbs': false,
      'maxCacheItems': 0,
      'sendDefaultPii': true,
      'enableWatchdogTerminationTracking': false,
      'enableNdkScopeSync': true,
      'enableAutoPerformanceTracing': false,
      'sendClientReports': false,
      'proguardUuid': fakeProguardUuid,
      'maxAttachmentSize': 10,
      'recordHttpBreadcrumbs': false,
      'captureFailedRequests': false,
      'enableAppHangTracking': false,
      'connectionTimeoutMillis': 9001,
      'readTimeoutMillis': 9002,
      'appHangTimeoutIntervalMillis': 9003,
      'proxy': {
        'host': 'localhost',
        'port': 8080,
        'type': 'HTTP',
        'user': 'admin',
        'pass': '0000',
      },
      'replay': <String, dynamic>{
        'quality': 'high',
        'sessionSampleRate': 0.1,
        'onErrorSampleRate': 0.2,
        'tags': {
          'maskAllText': true,
          'maskAllImages': true,
          'maskAssetImages': false,
          'maskingRules': ['Image: mask']
        }
      },
      'enableSpotlight': true,
      'spotlightUrl': 'http://localhost:8969/stream',
    });
  });
}

MethodChannel createChannelWithCallback(
  Future<dynamic>? Function(MethodCall call)? handler,
) {
  final channel = MethodChannel('initNativeSdk');
  // ignore: deprecated_member_use
  channel.setMockMethodCallHandler(handler);
  return channel;
}

SentryFlutterOptions createOptions() {
  final options = defaultTestOptions();
  options.sdk = SdkVersion(
    name: sdkName,
    version: sdkVersion,
  );
  options.sdk.addPackage('pub:sentry_flutter', sdkVersion);
  return options;
}

class Fixture {
  late SentryFlutterOptions options;
  SentryNativeChannel getSut(MethodChannel channel) {
    options = createOptions()..methodChannel = channel;
    return SentryNativeChannel(options);
  }
}
