import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/file_system_transport.dart';
import 'package:sentry_flutter/src/sentry_flutter_options.dart';
import 'package:sentry_flutter/src/version.dart';

import 'mocks.dart';

FutureOr<void> Function(SentryOptions) getConfigurationTester({
  bool isIOS = false,
  bool isWeb = false,
  bool isAndroid = false,
}) =>
    (options) async {
      assert(options is SentryFlutterOptions);
      options.dsn = fakeDsn;

      expect(kDebugMode, options.debug);
      expect('debug', options.environment);

      expect(!isWeb, options.transport is FileSystemTransport);

      expect(
        options.integrations.whereType<FlutterErrorIntegration>().length,
        1,
      );

      if (!isWeb) {
        expect(
          options.integrations.whereType<NativeSdkIntegration>().length,
          1,
        );
      }

      if (isIOS) {
        expect(
          options.integrations.whereType<LoadContextsIntegration>().length,
          1,
        );
      }

      if (isAndroid) {
        expect(
          options.integrations
              .whereType<LoadAndroidImageListIntegration>()
              .length,
          1,
        );
      }

      expect(
        options.integrations.whereType<LoadReleaseIntegration>().length,
        1,
      );

      expect(sdkName, options.sdk.name);
      expect(sdkVersion, options.sdk.version);
      expect('pub:sentry_flutter', options.sdk.packages.last.name);
      expect(sdkVersion, options.sdk.packages.last.version);

      // expect('packageName@version+buildNumber', options.release);
      // expect('buildNumber', options.dist);
    };
