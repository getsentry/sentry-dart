@TestOn('vm')
library file_test;

import 'dart:io';

import 'package:sentry/sentry.dart';
import 'package:sentry_file/sentry_file.dart';
import 'package:test/test.dart';

import 'mock_platform_checker.dart';
import 'mock_sentry_client.dart';

void main() {
  group('$File extension', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('io performance enabled wraps file', () async {
      final sut = fixture.getSut(
        tracesSampleRate: 1.0,
      );

      expect(sut is SentryFile, true);
    });

    test('io performance disabled does not wrap file', () async {
      final sut = fixture.getSut(
        tracesSampleRate: null,
      );

      expect(sut is SentryFile, false);
    });

    test('web does not wrap file', () async {
      final sut = fixture.getSut(
        tracesSampleRate: 1.0,
        isWeb: true,
      );

      expect(sut is SentryFile, false);
    });
  });
}

class Fixture {
  final options = defaultTestOptions();
  late Hub hub;

  File getSut({
    double? tracesSampleRate,
    bool isWeb = false,
  }) {
    options.tracesSampleRate = tracesSampleRate;
    options.platformChecker = MockPlatformChecker(isWeb);

    hub = Hub(options);

    final file = File('test_resources/testfile.txt');

    return file.sentryTrace(hub: hub);
  }
}
