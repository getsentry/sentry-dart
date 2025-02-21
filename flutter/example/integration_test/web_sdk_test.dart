// ignore_for_file: invalid_use_of_internal_member, avoid_web_libraries_in_flutter

@TestOn('browser')
library flutter_test;

import 'dart:async';
import 'dart:convert';
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
external SentryClient? _getClient();

@JS()
@staticInterop
class SentryClient {
  external factory SentryClient();
}

extension _SentryClientExtension on SentryClient {
  external void on(JSString event, JSFunction callback);

  external SentryOptions getOptions();
}

@JS()
@staticInterop
class SentryOptions {
  external factory SentryOptions();
}

extension _SentryOptionsExtension on SentryOptions {
  external JSString get dsn;
}

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
            options.dsn = fakeDsn;
          }, appRunner: () async {
            await tester.pumpWidget(const app.MyApp());
          });
        });

        expect(globalThis['Sentry'], isNotNull);

        final client = _getClient()!;
        final options = client.getOptions();

        final dsn = options.dsn.toDart;

        await Sentry.captureException(Exception('test'));

        expect(dsn, fakeDsn);
      });

      testWidgets('sends the correct envelope', (tester) async {
        SentryEvent? dartEvent;

        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((options) {
            options.dsn = fakeDsn;
            options.beforeSend = (event, hint) {
              dartEvent = event;
              return event;
            };
          }, appRunner: () async {
            await tester.pumpWidget(const app.MyApp());
          });
        });

        final client = _getClient()!;
        final completer = Completer<List<Object?>>();

        JSFunction beforeEnvelopeCallback = ((JSArray envelope) {
          final envelopDart = envelope.dartify() as List<Object?>;
          completer.complete(envelopDart);
        }).toJS;

        client.on('beforeEnvelope'.toJS, beforeEnvelopeCallback);

        final id = await Sentry.captureException(Exception('test'));

        final envelope = await completer.future;

        final header = envelope.first as Map<Object?, Object?>;
        expect(header['event_id'], id.toString());
        expect((header['sdk'] as Map<Object?, Object?>)['name'],
            'sentry.dart.flutter');

        final item = (envelope[1] as List).first as List<Object?>;
        final itemPayload =
            json.decode(utf8.decoder.convert(item[1] as List<int>))
                as Map<Object?, Object?>;

        final jsEventJson = (itemPayload).map((key, value) {
          return MapEntry(key.toString(), value as dynamic);
        });
        final dartEventJson = dartEvent!.toJson();

        // Make sure what we send from the Flutter layer is the same as what's being
        // sent in the JS layer
        expect(jsEventJson, equals(dartEventJson));
      });

      testWidgets('includes single-view supporting integrations',
          (tester) async {
        SentryFlutterOptions? confOptions;

        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((options) {
            options.dsn = fakeDsn;
            options.attachScreenshot = true;

            confOptions = options;
          }, appRunner: () async {
            await tester.pumpWidget(
              SentryWidget(child: const app.MyApp()),
            );
          });
        });
        expect(
          confOptions?.sdk.integrations.contains("screenshotIntegration"),
          isTrue,
        );
        expect(
          confOptions?.sdk.integrations.contains("widgetsBindingIntegration"),
          isTrue,
        );
        expect(
          find.byType(SentryScreenshotWidget),
          findsOneWidget,
        );
        expect(
          find.byType(SentryUserInteractionWidget),
          findsOneWidget,
        );
      });
    });

    group('disabled', () {
      testWidgets('Sentry JS SDK is not initialized', (tester) async {
        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((options) {
            options.dsn = fakeDsn;
            options.autoInitializeNativeSdk = false;
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
