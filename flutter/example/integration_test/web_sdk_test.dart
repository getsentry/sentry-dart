// ignore_for_file: invalid_use_of_internal_member, avoid_web_libraries_in_flutter

@TestOn('browser')
library flutter_test;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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

    tearDown(() async {
      await Sentry.close();
    });

    testWidgets('Sentry JS SDK is callable', (tester) async {
      final completer = Completer();
      const expectedMessage = 'test message';
      String actualMessage = '';

      await restoreFlutterOnErrorAfter(() async {
        await SentryFlutter.init((options) {
          options.dsn = fakeDsn;
        }, appRunner: () async {
          await tester.pumpWidget(const app.MyApp());
        });

        final beforeSendFn = (JSObject event, JSObject hint) {
          actualMessage = event.getProperty('message'.toJS).toString();
          completer.complete();
          return event;
        }.toJS;

        final options = {
          'dsn': app.exampleDsn,
          'beforeSend': beforeSendFn,
          'debug': true,
          'defaultIntegrations': [],
        }.jsify();

        _init(options);
        _captureMessage(expectedMessage.toJS);
      });

      await completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
        fail('beforeSend was not triggered');
      });

      expect(actualMessage, equals(expectedMessage));
    });

    testWidgets('Default: JS SDK initialized', (tester) async {
      await restoreFlutterOnErrorAfter(() async {
        await SentryFlutter.init((options) {
          options.dsn = fakeDsn;
        }, appRunner: () async {
          await tester.pumpWidget(const app.MyApp());
        });
      });

      expect(globalThis['Sentry'], isNotNull);
    });

    testWidgets('WebSdkIntegration removed: JS SDK not initialized',
        (tester) async {
      await restoreFlutterOnErrorAfter(() async {
        await SentryFlutter.init((options) {
          options.dsn = fakeDsn;
          // Remove WebSdkIntegration
          final integration = options.integrations.firstWhere((integration) =>
              integration.runtimeType.toString() == 'WebSdkIntegration');
          options.removeIntegration(integration);
        }, appRunner: () async {
          await tester.pumpWidget(const app.MyApp());
        });
      });

      expect(globalThis['Sentry'], isNull);
    });
  });
}
