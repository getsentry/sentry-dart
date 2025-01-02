// ignore_for_file: invalid_use_of_internal_member, avoid_web_libraries_in_flutter

@TestOn('browser')
library flutter_test;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/web/web_sentry_js_binding.dart';
import 'package:sentry_flutter_example/main.dart' as app;

import 'utils.dart';

@JS('globalThis')
external JSObject get globalThis;

@JS('Sentry.getClient')
external JSObject? _getClient();

void main() {
  group('Web SDK Integration', () {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();

    tearDown(() async {
      await Sentry.close();
    });

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
        expect(defaultIntegrations, isEmpty);
      });

      testWidgets(
          'capture unhandled exception: session contains status crashed',
          (tester) async {
        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((options) {
            options.enableSentryJs = true;
            options.dsn = fakeDsn;
          }, appRunner: () async {
            await tester.pumpWidget(const app.MyApp());
          });
        });

        final completer = Completer();
        SentryJsBridge.getClient().onBeforeEnvelope((envelope) {
          final envelopeDart = envelope.dartify() as List<dynamic>;

          final sessionEnvelope = envelopeDart.firstWhere((el) {
            if (el is List) {
              return (((el[0] as List)[0]) as Map<dynamic, dynamic>)
                  .containsValue('session');
            } else {
              return false;
            }
          }, orElse: () => null);

          expect(sessionEnvelope, isNotNull);
          final content =
              ((sessionEnvelope as List)[0][1] as Map<dynamic, dynamic>);
          expect(content['status'], 'crashed');

          completer.complete();
        });

        final mechanism = Mechanism(type: 'FlutterError', handled: false);
        final throwableMechanism =
            ThrowableMechanism(mechanism, Exception('test exception'));

        await Sentry.captureException(throwableMechanism);

        await completer.future.timeout(const Duration(seconds: 5),
            onTimeout: () {
          fail('beforeEnvelope was not triggered');
        });
      });

      testWidgets('capture handled exception: session contains status ok',
          (tester) async {
        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((options) {
            options.enableSentryJs = true;
            options.dsn = fakeDsn;
          }, appRunner: () async {
            await tester.pumpWidget(const app.MyApp());
          });
        });

        final completer = Completer();
        SentryJsBridge.getClient().onBeforeEnvelope((envelope) {
          final envelopeDart = envelope.dartify() as List<dynamic>;

          final sessionEnvelope = envelopeDart.firstWhere((el) {
            if (el is List) {
              return (((el[0] as List)[0]) as Map<dynamic, dynamic>)
                  .containsValue('session');
            } else {
              return false;
            }
          }, orElse: () => null);

          expect(sessionEnvelope, isNotNull);
          final content =
              ((sessionEnvelope as List)[0][1] as Map<dynamic, dynamic>);
          expect(content['status'], 'ok');

          completer.complete();
        });

        await Sentry.captureException(Exception('test exception'));

        await completer.future.timeout(const Duration(seconds: 5),
            onTimeout: () {
          fail('beforeEnvelope was not triggered');
        });
      });

      testWidgets(
          'when capturing exceptions then session contains error counts',
          (tester) async {
        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((options) {
            options.enableSentryJs = true;
            options.dsn = fakeDsn;
          }, appRunner: () async {
            await tester.pumpWidget(const app.MyApp());
          });
        });

        final completer = Completer();
        SentryJsBridge.getClient().onBeforeEnvelope((envelope) {
          final envelopeDart = envelope.dartify() as List<dynamic>;

          final sessionEnvelope = envelopeDart.firstWhere((el) {
            if (el is List) {
              return (((el[0] as List)[0]) as Map<dynamic, dynamic>)
                  .containsValue('session');
            } else {
              return false;
            }
          }, orElse: () => null);

          expect(sessionEnvelope, isNotNull);
          final content =
              ((sessionEnvelope as List)[0][1] as Map<dynamic, dynamic>);
          expect(content['status'], 'ok');

          completer.complete();
        });

        await Sentry.captureException(Exception('test exception'));
        await Sentry.captureException(Exception('test exception'));
        await Sentry.captureException(Exception('test exception'));
        await Sentry.captureException(Exception('test exception'));

        await completer.future.timeout(const Duration(seconds: 5),
            onTimeout: () {
          fail('beforeEnvelope was not triggered');
        });
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

extension SentryJsClientHelpers on SentryJsClient {
  void onBeforeEnvelope(void Function(JSArray envelope) callback) {
    on('beforeEnvelope'.toJS, callback.toJS);
  }
}
