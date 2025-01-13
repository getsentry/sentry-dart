// ignore_for_file: invalid_use_of_internal_member, avoid_web_libraries_in_flutter

@TestOn('browser')
library flutter_test;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter_example/main.dart' as app;

import 'utils.dart';

@JS('globalThis')
external JSObject get globalThis;

@JS('Sentry.getClient')
external JSObject? _getClient();

void main() {
  group('Web SDK Integration', () {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();

    group('enabled', () {
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

        final client = _getClient()!;
        final options = client.callMethod('getOptions'.toJS)! as JSObject;

        final dsn = options.getProperty('dsn'.toJS).toString();
        final defaultIntegrations = options
            .getProperty('defaultIntegrations'.toJS)
            .dartify() as List<Object?>;

        expect(dsn, fakeDsn);
        expect(defaultIntegrations, isNotEmpty);
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
        expect(() => _getClient(), throwsA(anything));
      });
    });
  });
}
