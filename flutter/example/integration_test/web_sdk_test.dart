// ignore_for_file: invalid_use_of_internal_member

@TestOn('browser')
library flutter_test;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/web_sdk_integration.dart';
import 'package:sentry_flutter_example/main.dart' as app;

import 'utils.dart';

// We can use dart:html, this is meant to be tested on Flutter Web and not WASM
// This integration test can be changed later when we actually do support WASM

void main() {
  group('Web SDK Integration', () {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();

    tearDown(() async {
      await Sentry.close();
    });

    testWidgets('Production mode: injects correct script', (tester) async {
      await SentryFlutter.init((options) {
        defaultTestOptionsInitializer(options);
        options.platformChecker = _FakePlatformChecker(isDebug: false);
      }, appRunner: () async {
        await tester.pumpWidget(const app.MyApp());
      });

      final scripts = document
          .querySelectorAll('script')
          .map((script) => script as ScriptElement)
          .toList();

      expect(scripts.first.src, contains('bundle.tracing.min.js'));
      expect(scripts.first.integrity, isNotEmpty);
      expect(scripts.first.crossOrigin, isNotEmpty);
    });

    testWidgets('Debug mode: injects correct script', (tester) async {
      // by default in debug mode, no need to add fake platform checker
      await SentryFlutter.init(defaultTestOptionsInitializer,
          appRunner: () async {
        await tester.pumpWidget(const app.MyApp());
      });

      final scripts = document
          .querySelectorAll('script')
          .map((script) => script as ScriptElement)
          .toList();

      expect(scripts.first.src, contains('bundle.tracing.js'));
      expect(scripts.first.integrity, isNotEmpty);
      expect(scripts.first.crossOrigin, isNotEmpty);
    });

    testWidgets('Adds Integration', (tester) async {
      await SentryFlutter.init(defaultTestOptionsInitializer,
          appRunner: () async {
        await tester.pumpWidget(const app.MyApp());
      });

      final integrations = Sentry.currentHub.options.integrations;
      expect(integrations, contains(isA<WebSdkIntegration>()));
    });
  });
}

class _FakePlatformChecker extends PlatformChecker {
  _FakePlatformChecker({
    this.isDebug = false,
  });

  final bool isDebug;

  @override
  bool isDebugMode() => isDebug;
}
