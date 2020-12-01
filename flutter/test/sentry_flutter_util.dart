import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/file_system_transport.dart';
import 'package:sentry_flutter/src/version.dart';

import 'mocks.dart';

FutureOr<void> Function(SentryOptions) getConfigurationTester({
  bool isIOS = false,
  bool isWeb = false,
}) =>
    (SentryOptions options) async {
      options.dsn = fakeDsn;

      expect(kDebugMode, options.debug);
      expect('debug', options.environment);

      expect(true, options.transport is FileSystemTransport);

      expect(
        options.integrations.whereType<FlutterErrorIntegration>().length,
        1,
      );

      if (isIOS) {
        expect(5, options.integrations.length);
      } else {
        expect(4, options.integrations.length);
      }

      expect(sdkName, options.sdk.name);
      expect(sdkVersion, options.sdk.version);
      expect('pub:sentry_flutter', options.sdk.packages.last.name);
      expect(sdkVersion, options.sdk.packages.last.version);

      expect('packageName@version+buildNumber', options.release);
      expect('buildNumber', options.dist);
    };
