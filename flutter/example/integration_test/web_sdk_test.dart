// ignore_for_file: invalid_use_of_internal_member

@TestOn('browser')
library flutter_test;

// ignore: avoid_web_libraries_in_flutter
import 'dart:js';
import 'dart:js_interop';

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
      await SentryFlutter.init(defaultTestOptionsInitializer,
          appRunner: () async {
        await tester.pumpWidget(const app.MyApp());
      });

      const expectedMessage = 'test message';
      final beforeSendFn = JsFunction.withThis((thisArg, event, hint) {
        final actualMessage = event['message'];
        expect(actualMessage, equals(actualMessage));

        return event;
      });

      final Map<String, dynamic> options = {
        'dsn': app.exampleDsn,
        'beforeSend': beforeSendFn,
        'defaultIntegrations': [],
      };

      final sentry = context['Sentry'] as JsObject;
      sentry.callMethod('init', [JsObject.jsify(options)]);

      sentry.callMethod('captureMessage', [expectedMessage.toJS]);
    });
  });
}
