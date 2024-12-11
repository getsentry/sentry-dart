// ignore_for_file: invalid_use_of_internal_member, avoid_web_libraries_in_flutter

@TestOn('browser')
library flutter_test;

import 'dart:async';
import 'dart:js';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter_example/main.dart' as app;

import 'utils.dart';

// We can use dart:html, this is meant to be tested on Flutter Web and not WASM
// This integration test can be changed later when we actually do support WASM

void main() {
  group('Web SDK Integration', () {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();

    tearDown(() async {
      await Sentry.close();
      // Clean up any existing Sentry object from previous tests
      context['Sentry'] = null;
    });

    testWidgets('Sentry JS SDK is callable', (tester) async {
      final completer = Completer();
      const expectedMessage = 'test message';
      String actualMessage = '';

      await restoreFlutterOnErrorAfter(() async {
        await SentryFlutter.init((options) {
          options.dsn = app.exampleDsn;
        }, appRunner: () async {
          await tester.pumpWidget(const app.MyApp());
        });

        final beforeSendFn = JsFunction.withThis((thisArg, event, hint) {
          actualMessage = event['message'];
          completer.complete();
          return event;
        });

        final Map<String, dynamic> options = {
          'dsn': app.exampleDsn,
          'beforeSend': beforeSendFn,
          'defaultIntegrations': [],
        };

        final sentry = context['Sentry'] as JsObject;
        sentry.callMethod('init', [JsObject.jsify(options)]);
        sentry.callMethod('captureMessage', [expectedMessage]);
      });

      await completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
        fail('beforeSend was not triggered');
      });

      expect(actualMessage, equals(expectedMessage));
    });

    testWidgets('Sentry JS SDK is automatically initialized', (tester) async {
      const expectedDsn = 'https://random@def.ingest.sentry.io/1234567';
      const expectedRelease = 'my-random-release';
      const expectedSampleRate = 0.2;
      const expectedEnv = 'my-random-env';
      const expectedDist = '999';
      const expectedAttachStacktrace = false;
      const expectedMaxBreadcrumbs = 1000;
      const expectedDebug = true;

      dynamic jsOptions;

      await restoreFlutterOnErrorAfter(() async {
        await SentryFlutter.init((options) {
          options.dsn = expectedDsn;
          options.debug = expectedDebug;
          options.release = expectedRelease;
          options.sampleRate = expectedSampleRate;
          options.environment = expectedEnv;
          options.dist = expectedDist;
          options.attachStacktrace = expectedAttachStacktrace;
          options.maxBreadcrumbs = expectedMaxBreadcrumbs;
        }, appRunner: () async {
          await tester.pumpWidget(const app.MyApp());
        });

        final sentry = context['Sentry'] as JsObject;
        jsOptions = sentry.callMethod('getClient').callMethod('getOptions');
      });

      // Test all options mapped from Dart to JS
      expect(jsOptions['dsn'], equals(expectedDsn));
      expect(jsOptions['debug'], equals(expectedDebug));
      expect(jsOptions['environment'], equals(expectedEnv));
      expect(jsOptions['release'], equals(expectedRelease));
      expect(jsOptions['dist'], equals(expectedDist));
      expect(jsOptions['sampleRate'], equals(expectedSampleRate));
      expect(jsOptions['attachStacktrace'], equals(expectedAttachStacktrace));
      expect(jsOptions['maxBreadcrumbs'], equals(expectedMaxBreadcrumbs));
      expect(jsOptions['defaultIntegrations'], isEmpty);
    });

    testWidgets('Sentry JS SDK is not available without WebSdkIntegration',
        (tester) async {
      await restoreFlutterOnErrorAfter(() async {
        await SentryFlutter.init((options) {
          options.dsn = app.exampleDsn;
          // Remove WebSdkIntegration
          final integration = options.integrations.firstWhere((integration) =>
              integration.runtimeType.toString() == 'WebSdkIntegration');
          options.removeIntegration(integration);
        }, appRunner: () async {
          await tester.pumpWidget(const app.MyApp());
        });
      });

      expect(context['Sentry'], isNull);
    });
  });
}
