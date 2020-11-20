import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info/package_info.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'sentry_flutter_util.dart';

void main() {
  const MethodChannel _channel = MethodChannel('sentry_flutter');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {});
  });

  tearDown(() {
    _channel.setMockMethodCallHandler(null);
    Sentry.close();
  });

  test('Flutter init for mobile will run default configurations', () async {
    await SentryFlutter.init(
      configurationTester,
      callback,
      packageLoader: loadTestPackage,
    );
  });
}

void callback() {}

Future<PackageInfo> loadTestPackage() async {
  return PackageInfo(
    appName: 'appName',
    packageName: 'packageName',
    version: 'version',
    buildNumber: 'buildNumber',
  );
}
