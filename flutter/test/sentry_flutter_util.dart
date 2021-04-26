import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/file_system_transport.dart';
import 'package:sentry_flutter/src/sentry_flutter_options.dart';

import 'mocks.dart';

FutureOr<void> Function(SentryFlutterOptions) getConfigurationTester({
  required List<Type> shouldHaveIntegrations,
  required List<Type> shouldNotHaveIntegrations,
  required bool hasFileSystemTransport,
}) =>
    (options) async {
      options.dsn = fakeDsn;

      expect(
        options.transport is FileSystemTransport,
        hasFileSystemTransport,
        reason: '$FileSystemTransport was wrongly set',
      );

      for (final type in shouldHaveIntegrations) {
        final integrations = options.integrations
            .where((element) => element.runtimeType == type)
            .toList();
        expect(integrations.length, 1);
      }

      for (final type in shouldNotHaveIntegrations) {
        final integrations = options.integrations
            .where((element) => element.runtimeType == type)
            .toList();
        expect(integrations.isEmpty, true);
      }
    };
