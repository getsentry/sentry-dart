// ignore_for_file: invalid_use_of_internal_member, avoid_web_libraries_in_flutter

@TestOn('browser')
library flutter_test;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/web/script_loader/sentry_script_loader.dart';
import 'package:sentry_flutter/src/web/sentry_js_bundle.dart';
import 'package:sentry_flutter_example/main.dart' as app;

import 'utils.dart';

@JS('globalThis')
external JSObject get globalThis;

@JS('Sentry.init')
external void _init(JSAny? options);

@JS('Sentry.captureMessage')
external void _captureMessage(JSAny? message);

void main() {
  group('Web SDK Integration', () {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();

    group('enabled', () {
      testWidgets('Sentry JS SDK is callable', (tester) async {
        final completer = Completer<String>();
        const expectedMessage = 'test message';

        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((options) {
            options.enableSentryJs = true;
            // we need to set this to false so the sdk does not init automatically and
            // we can pass the native beforeSend function
            options.autoInitializeNativeSdk = false;
            options.dsn = fakeDsn;
          }, appRunner: () async {
            await tester.pumpWidget(const app.MyApp());
          });
        });

        final loader = SentryScriptLoader();
        await loader.loadWebSdk(productionScripts);

        final beforeSendFn = (JSObject event, JSObject hint) {
          completer.complete(event.getProperty('message'.toJS).toString());
          return event;
        }.toJS;

        final options = {
          'dsn': app.exampleDsn,
          'beforeSend': beforeSendFn,
          'defaultIntegrations': [],
        }.jsify();
        _init(options);
        _captureMessage(expectedMessage.toJS);

        final actualMessage = await completer.future
            .timeout(const Duration(seconds: 5), onTimeout: () {
          fail('beforeSend was not triggered');
        });

        expect(actualMessage, equals(expectedMessage));
      });

      testWidgets('Sentry JS SDK initialized', (tester) async {
        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((options) {
            options.enableSentryJs = true;
            options.dsn = fakeDsn;
          }, appRunner: () async {
            await tester.pumpWidget(const app.MyApp());
          });
        });

        expect(globalThis['Sentry'], isNotNull);
      });
    });

    group('disabled', () {
      testWidgets('Sentry JS SDK is not initialized', (tester) async {
        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((options) {
            options.enableSentryJs = false;
            options.dsn = fakeDsn;
          }, appRunner: () async {
            await tester.pumpWidget(const app.MyApp());
          });
        });

        expect(globalThis['Sentry'], isNull);
      });
    });
  });
}
