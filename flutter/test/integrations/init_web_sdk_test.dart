import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/version.dart';
import 'package:sentry_flutter/src/web/sentry_js_bridge.dart';
import 'package:sentry_flutter/src/web/sentry_web_interop.dart';

import '../mocks.dart';

// todo
void main() {
  late Fixture fixture;
  setUp(() {
    fixture = Fixture();
  });

  test('test default values', () async {
    // String? methodName;
    // dynamic arguments;
    //
    // var sut = fixture.getSut(channel);
    //
    // await sut.init(fixture.options);
    //
    // channel.setMethodCallHandler(null);
    //
    // expect(methodName, 'initNativeSdk');
    // expect(arguments, <String, dynamic>{
    //   'dsn': fakeDsn,
    //   'debug': false,
    //   'environment': null,
    //   'release': null,
    //   'enableAutoSessionTracking': true,
    //   'enableNativeCrashHandling': true,
    //   'attachStacktrace': true,
    //   'attachThreads': false,
    //   'autoSessionTrackingIntervalMillis': 30000,
    //   'dist': null,
    //   'integrations': <String>[],
    //   'packages': [
    //     {'name': 'pub:sentry_flutter', 'version': sdkVersion}
    //   ],
    //   'diagnosticLevel': 'debug',
    //   'maxBreadcrumbs': 100,
    //   'anrEnabled': false,
    //   'anrTimeoutIntervalMillis': 5000,
    //   'enableAutoNativeBreadcrumbs': true,
    //   'maxCacheItems': 30,
    //   'sendDefaultPii': false,
    //   'enableWatchdogTerminationTracking': true,
    //   'enableNdkScopeSync': true,
    //   'enableAutoPerformanceTracing': true,
    //   'sendClientReports': true,
    //   'proguardUuid': null,
    //   'maxAttachmentSize': 20 * 1024 * 1024,
    //   'recordHttpBreadcrumbs': true,
    //   'captureFailedRequests': true,
    //   'enableAppHangTracking': true,
    //   'connectionTimeoutMillis': 5000,
    //   'readTimeoutMillis': 5000,
    //   'appHangTimeoutIntervalMillis': 2000,
    // });
  });
}

SentryFlutterOptions createOptions() {
  final mockPlatformChecker = MockPlatformChecker(isWebValue: true);
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
  late SentryFlutterOptions options;
  SentryWebInterop getSut(SentryJsApi jsBridge) {
    options = createOptions();
    return SentryWebInterop(jsBridge, options);
  }
}
