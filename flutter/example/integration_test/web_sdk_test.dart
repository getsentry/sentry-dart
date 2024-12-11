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
      dynamic jsOptions;
      SentryFlutterOptions? dartOptions;
      await restoreFlutterOnErrorAfter(() async {
        await SentryFlutter.init((options) {
          options.dsn = app.exampleDsn;
          options.release = 'my-random-release';
          options.sampleRate = 0.2;
          dartOptions = options;
        }, appRunner: () async {
          await tester.pumpWidget(const app.MyApp());
        });

        final sentry = context['Sentry'] as JsObject;
        jsOptions = sentry.callMethod('getClient').callMethod('getOptions');
      });

      // Test all options mapped from Dart to JS
      expect(jsOptions['dsn'], dartOptions!.dsn);
      expect(jsOptions['debug'], dartOptions!.debug);
      expect(jsOptions['environment'], dartOptions!.environment);
      expect(jsOptions['release'], dartOptions!.release);
      expect(jsOptions['dist'], dartOptions!.dist);
      expect(jsOptions['sampleRate'], dartOptions!.sampleRate);
      expect(jsOptions['attachStacktrace'], dartOptions!.attachStacktrace);
      expect(jsOptions['maxBreadcrumbs'], dartOptions!.maxBreadcrumbs);
      expect(jsOptions['defaultIntegrations'], isEmpty);
    });
  });
}
