@TestOn('browser')
library flutter_test;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/web_sdk_integration.dart';
import 'package:sentry_flutter_example/main.dart' as app;

// We can use dart:html, this is meant to be tested on Flutter Web and not WASM
// This integration test can be changed later when we actually do support WASM

void main() {
  group('Web SDK Integration', () {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();

    tearDown(() async {
      await Sentry.close();
    });

    testWidgets('Injects script into document head', (tester) async {
      await SentryFlutter.init((options) {
        options.dsn = 'https://abc@def.ingest.sentry.io/1234567';
        // ignore: invalid_use_of_internal_member
        options.automatedTestMode = true;
      }, appRunner: () async {
        await tester.pumpWidget(const app.MyApp());
      });

      final scripts = document
          .querySelectorAll('script')
          .map((script) => script as ScriptElement)
          .toList();

      // should inject the debug script
      expect(scripts.first.src, contains('bundle.tracing.js'));
    });

    testWidgets('Adds Integration', (tester) async {
      await SentryFlutter.init((options) {
        options.dsn = 'https://abc@def.ingest.sentry.io/1234567';
        // ignore: invalid_use_of_internal_member
        options.automatedTestMode = true;
      }, appRunner: () async {
        await tester.pumpWidget(const app.MyApp());
      });

      // ignore: invalid_use_of_internal_member
      final integrations = Sentry.currentHub.options.integrations;
      expect(integrations, contains(isA<WebSdkIntegration>()));
    });
  });
}
