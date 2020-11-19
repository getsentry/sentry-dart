import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/default_integrations.dart';
import 'package:sentry_flutter/file_system_transport.dart';
import 'package:sentry_flutter/version.dart';

import 'mocks.dart';

FutureOr<void> configurationTester(
  SentryOptions options, {
  bool isWeb = false,
}) async {
  options.dsn = fakeDsn;

  expect(kDebugMode, options.debug);
  expect('debug', options.environment);

  expect(true, options.transport is FileSystemTransport);

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

  expect('packageName@version+buildNumber', options.release);
  expect('buildNumber', options.dist);
}
