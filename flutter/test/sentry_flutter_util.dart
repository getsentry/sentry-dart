import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/file_system_transport.dart';
import 'package:sentry_flutter/src/sentry_flutter_options.dart';

import 'mocks.dart';

FutureOr<void> Function(SentryFlutterOptions) getConfigurationTester({
  required Iterable<Type> shouldHaveIntegrations,
  required Iterable<Type> shouldNotHaveIntegrations,
  required bool hasFileSystemTransport,
}) =>
    (options) async {
      options.dsn = fakeDsn;

      expect(
        options.transport is FileSystemTransport,
        hasFileSystemTransport,
        reason: '$FileSystemTransport was wrongly set',
      );

      final integrations = <Type, int>{};
      for (var e in options.integrations) {
        integrations[e.runtimeType] = integrations[e.runtimeType] ?? 0 + 1;
      }

      for (final type in shouldHaveIntegrations) {
        expect(integrations, containsPair(type, 1));
      }

      shouldNotHaveIntegrations = Set.of(shouldNotHaveIntegrations)
          .difference(Set.of(shouldHaveIntegrations));
      for (final type in shouldNotHaveIntegrations) {
        expect(integrations, isNot(contains(type)));
      }
    };
