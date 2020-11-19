import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info/package_info.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/default_integrations.dart';
import 'package:sentry_flutter/file_system_transport.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/version.dart';

import 'mocks.dart';

void main() {
  const MethodChannel _channel = MethodChannel('sentry_flutter');
  const MethodChannel _piChannel =
      MethodChannel('plugins.flutter.io/package_info');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {});
    _piChannel.setMockMethodCallHandler((MethodCall methodCall) async {
      return PackageInfo(
        appName: 'appName',
        packageName: 'packageName',
        version: 'version',
        buildNumber: 'buildNumber',
      );
    });
  });

  tearDown(() {
    _channel.setMockMethodCallHandler(null);
    _piChannel.setMockMethodCallHandler(null);
    Sentry.close();
  });

  test('nativeSdkIntegration wont throw', () async {
    await SentryFlutter.init(configuration, callback);
  });
}

void callback() {}

void configuration(SentryOptions options) {
  options.dsn = fakeDsn;
  expect(kDebugMode, options.debug);

  expect(true, options.transport is FileSystemTransport);
  // expect('buildNumber', options.dist);
  // expect('packageName@version+buildNumber', options.release);

  expect(
      options.integrations
          .where((element) => element == flutterErrorIntegration),
      isNotEmpty);

  expect(
      options.integrations
          .where((element) => element == isolateErrorIntegration),
      isNotEmpty);

  expect(4, options.integrations.length);

  expect(sdkName, options.sdk.name);
  expect(sdkVersion, options.sdk.version);
  expect('pub:sentry_flutter', options.sdk.packages.last.name);
  expect(sdkVersion, options.sdk.packages.last.version);
}
