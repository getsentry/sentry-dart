// ignore_for_file: invalid_use_of_internal_member, avoid_web_libraries_in_flutter

@TestOn('browser')
library flutter_test;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/web/javascript_transport.dart';
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
  external JSArray get defaultIntegrations;
}

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
        final options = client.getOptions();

        final dsn = options.dsn.toDart;
        final defaultIntegrations = options.defaultIntegrations.toDart;

        await Sentry.captureException(Exception('test'));

        expect(dsn, fakeDsn);
        expect(defaultIntegrations, isEmpty);
      });

      testWidgets('sends the correct envelope', (tester) async {
        SentryFlutterOptions? configuredOptions;
        SentryEvent? dartEvent;

        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((options) {
            options.enableSentryJs = true;
            options.dsn = app.exampleDsn;
            options.beforeSend = (event, hint) {
              dartEvent = event;
              return event;
            };
            configuredOptions = options;
          }, appRunner: () async {
            await tester.pumpWidget(const app.MyApp());
          });
        });

        expect(configuredOptions!.transport, isA<JavascriptTransport>());

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

        final item = (envelope[1] as List<Object?>).first as List<Object?>;
        final itemPayload = item[1] as Map<Object?, Object?>;
        final jsEventJson = (itemPayload).map((key, value) {
          return MapEntry(key.toString(), value as dynamic);
        });
        final dartEventJson = dartEvent!.toJson();

        // Make sure what we send from the Flutter layer is the same as what's being
        // sent in the JS layer
        expect(jsEventJson, equals(dartEventJson));
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
