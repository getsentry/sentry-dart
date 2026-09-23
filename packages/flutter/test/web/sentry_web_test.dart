@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/envelope/sentry_envelope_header.dart';
import 'package:sentry/src/envelope/sentry_envelope_item_header.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/replay/replay_config.dart';
import 'package:sentry_flutter/src/web/script_loader/sentry_script_loader.dart';
import 'package:sentry_flutter/src/web/sentry_js_binding.dart';
import 'package:sentry_flutter/src/web/sentry_js_bundle.dart';
import 'package:sentry_flutter/src/web/sentry_web.dart';
import 'package:sentry_flutter/src/sessions/web_session_handler.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  group(SentryWeb, () {
    late SentryFlutterOptions options;
    late Hub hub;

    setUp(() {
      hub = MockHub();
      options = defaultTestOptions();
    });

    group('with real binding', () {
      late SentryWeb sut;
      late SentryJsBinding binding;

      setUp(() async {
        final loader = SentryScriptLoader(options: options);
        await loader.loadWebSdk(debugScripts);
        binding = createJsBinding();
        sut = SentryWeb(binding, options);
      });

      tearDown(() async {
        await sut.close();
      });

      test('init: options mapped to JS SDK', () async {
        const expectedDsn = 'https://random@def.ingest.sentry.io/1234567';
        const expectedRelease = 'my-random-release';
        const expectedSampleRate = 0.2;
        const expectedEnv = 'my-random-env';
        const expectedDist = '999';
        const expectedAttachStacktrace = false;
        const expectedMaxBreadcrumbs = 1000;
        const expectedDebug = true;

        options.dsn = expectedDsn;
        options.release = expectedRelease;
        options.sampleRate = expectedSampleRate;
        options.environment = expectedEnv;
        options.dist = expectedDist;
        options.attachStacktrace = expectedAttachStacktrace;
        options.maxBreadcrumbs = expectedMaxBreadcrumbs;
        options.debug = expectedDebug;

        // quick check that Sentry is not initialized first
        expect(() => binding.getJsOptions()['dsn'], throwsA(anything));

        await sut.init(hub);

        final jsOptions = binding.getJsOptions();

        expect(jsOptions['dsn'], expectedDsn);
        expect(jsOptions['release'], expectedRelease);
        expect(jsOptions['sampleRate'], expectedSampleRate);
        expect(jsOptions['environment'], expectedEnv);
        expect(jsOptions['dist'], expectedDist);
        expect(jsOptions['attachStacktrace'], expectedAttachStacktrace);
        expect(jsOptions['maxBreadcrumbs'], expectedMaxBreadcrumbs);
        expect(jsOptions['debug'], expectedDebug);
        expect(jsOptions['defaultIntegrations'].length, 2);
        expect(
          jsOptions['defaultIntegrations'][0].toString(),
          contains('name: GlobalHandlers'),
        );
        expect(
          jsOptions['defaultIntegrations'][1].toString(),
          contains('name: Dedupe'),
        );
      });

      test(
        'uses restrictive JS collection defaults when PII is disabled',
        () async {
          await sut.init(hub);
          final sentry = _globalThis['Sentry'] as JSObject;
          final client = sentry.callMethod<JSObject>('getClient'.toJS);
          final collection = client
              .callMethod<JSObject>('getDataCollectionOptions'.toJS)
              .dartify();
          expect(collection, {
            'userInfo': false,
            'cookies': false,
            'httpHeaders': {
              'request': {
                'deny': ['forwarded', '-ip', 'remote-', 'via', '-user'],
              },
              'response': {
                'deny': ['forwarded', '-ip', 'remote-', 'via', '-user'],
              },
            },
            'httpBodies': <String>[],
            'urlQueryParams': {
              'deny': ['forwarded', '-ip', 'remote-', 'via', '-user'],
            },
            'graphQL': {'document': false, 'variables': false},
            'genAI': {'inputs': false, 'outputs': false},
            'databaseQueryData': false,
            'queues': false,
            'stackFrameVariables': true,
            'frameContextLines': 5,
          });
        },
      );

      test('allows JS collection when PII is enabled', () async {
        options.sendDefaultPii = true;
        await sut.init(hub);
        final sentry = _globalThis['Sentry'] as JSObject;
        final client = sentry.callMethod<JSObject>('getClient'.toJS);
        final collection = client
            .callMethod<JSObject>('getDataCollectionOptions'.toJS)
            .dartify();
        expect(collection, {
          'userInfo': true,
          'cookies': true,
          'httpHeaders': {'request': true, 'response': true},
          'httpBodies': [
            'incomingRequest',
            'outgoingRequest',
            'incomingResponse',
            'outgoingResponse',
          ],
          'urlQueryParams': true,
          'graphQL': {'document': true, 'variables': true},
          'genAI': {'inputs': true, 'outputs': true},
          'databaseQueryData': true,
          'queues': true,
          'stackFrameVariables': true,
          'frameContextLines': 5,
        });
      });

      for (final sendDefaultPii in <bool?>[null, false, true]) {
        test(
          'gates native JS error IP collection with sendDefaultPii=$sendDefaultPii',
          () async {
            if (sendDefaultPii != null) {
              options.sendDefaultPii = sendDefaultPii;
            }
            await sut.init(hub);

            final sentry = _globalThis['Sentry'] as JSObject;
            final client = sentry.callMethod<JSObject>('getClient'.toJS);
            final event = Completer<Map<dynamic, dynamic>>();
            client.callMethod<JSAny?>(
              'on'.toJS,
              'beforeEnvelope'.toJS,
              ((JSArray captured) {
                final envelope = captured.dartify() as List;
                event.complete(
                  ((envelope[1] as List).first as List)[1]
                      as Map<dynamic, dynamic>,
                );
              }).toJS,
            );
            final error = _globalThis.callMethod<JSObject>(
              'Error'.toJS,
              'PII regression'.toJS,
            );
            sentry.callMethod<JSAny?>('captureException'.toJS, error);

            final captured = await event.future.timeout(
              const Duration(seconds: 5),
            );
            final sdk = captured['sdk'] as Map<dynamic, dynamic>;
            expect(
              (sdk['settings'] as Map)['infer_ip'],
              sendDefaultPii == true ? 'auto' : 'never',
            );
          },
        );
      }

      for (final jsFirst in [true, false]) {
        test(
          'keeps mixed JS and Dart errors unhandled with jsFirst=$jsFirst',
          () async {
            options.release = 'session-test';
            await sut.init(hub);
            await sut.startSession();
            final sentry = _globalThis['Sentry'] as JSObject;
            final client = sentry.callMethod<JSObject>('getClient'.toJS);
            final sessions = <Map<dynamic, dynamic>>[];
            client.callMethod<JSAny?>(
              'on'.toJS,
              'beforeSendSession'.toJS,
              ((JSObject session) {
                sessions.add(session.dartify() as Map<dynamic, dynamic>);
              }).toJS,
            );
            final sent = Completer<void>();
            client.callMethod<JSAny?>(
              'on'.toJS,
              'beforeEnvelope'.toJS,
              ((JSArray envelope) {
                final items = (envelope.dartify() as List)[1] as List;
                if (((items.first as List).first as Map)['type'] == 'event') {
                  sent.complete();
                }
              }).toJS,
            );
            final event = SentryEvent(
              exceptions: [
                SentryException(
                  type: 'test',
                  value: 'test',
                  mechanism: Mechanism(type: 'test', handled: false),
                ),
              ],
            );
            Future<void> captureJsError() async {
              sentry.callMethod<JSAny?>(
                'captureEvent'.toJS,
                event.toJson().jsify(),
              );
              await sent.future.timeout(const Duration(seconds: 5));
            }

            final handler = WebSessionHandler(sut);
            if (jsFirst) {
              await captureJsError();
              await handler.updateSessionFromEvent(event);
            } else {
              await handler.updateSessionFromEvent(event);
              await captureJsError();
            }
            expect(sessions, hasLength(1));
            expect(sessions.single['status'], 'unhandled');
            expect(sessions.single['errors'], 1);
            expect((await sut.getSession())?['status'], 'unhandled');
          },
        );
      }

      test('options getter returns the original options', () {
        expect(sut.options, same(options));
      });

      test('native features are not supported', () {
        expect(sut.supportsLoadContexts, isFalse);
        expect(sut.supportsReplay, isFalse);
      });

      test('capturing envelope is supported', () {
        expect(sut.supportsCaptureEnvelope, isTrue);
      });

      test('can send envelope without throwing', () async {
        await sut.init(hub);

        await sut.captureStructuredEnvelope(
          SentryEnvelope.fromEvent(
            SentryEvent(),
            SdkVersion(name: 'test', version: '0'),
          ),
        );
      });

      test(
        'loadDebugImages returns null if no debug ids are available',
        () async {
          await sut.init(hub);
          _globalThis['_sentryDebugIds'] = null;

          final frames = [
            SentryStackFrame(absPath: 'http://127.0.0.1:8080/main.dart.js'),
          ];
          final stackTrace = SentryStackTrace(frames: frames);
          final images = await sut.loadDebugImages(stackTrace);

          expect(images, isNull);
        },
      );

      test(
        'loadDebugImages returns null if no matching absPath or filename',
        () async {
          await sut.init(hub);
          _globalThis['_sentryDebugIds'] = debugIdMap.jsify();

          final frames = [SentryStackFrame(absPath: 'abc', fileName: 'def')];
          final stackTrace = SentryStackTrace(frames: frames);
          final images = await sut.loadDebugImages(stackTrace);

          expect(images, isNull);
        },
      );

      test(
        'loadDebugImages loads debug id to debug images with matching absPath',
        () async {
          await sut.init(hub);
          _globalThis['_sentryDebugIds'] = debugIdMap.jsify();

          final frames = [
            SentryStackFrame(absPath: 'http://127.0.0.1:8080/main.dart.js'),
          ];
          final stackTrace = SentryStackTrace(frames: frames);
          final images = await sut.loadDebugImages(stackTrace);

          expect(images, isNotNull);
          expect(images!.length, 1);
          expect(images.first.codeFile, frames.first.absPath);
          expect(images.first.debugId, debugId);
        },
      );

      test(
        'loadDebugImages loads debug id to debug images with matching filename',
        () async {
          await sut.init(hub);
          _globalThis['_sentryDebugIds'] = debugIdMap.jsify();

          final frames = [
            SentryStackFrame(fileName: 'http://127.0.0.1:8080/main.dart.js'),
          ];
          final stackTrace = SentryStackTrace(frames: frames);
          final images = await sut.loadDebugImages(stackTrace);

          expect(images, isNotNull);
          expect(images!.length, 1);
          expect(images.first.codeFile, frames.first.fileName);
          expect(images.first.debugId, debugId);
        },
      );
    });

    group('with mock binding', () {
      late MockSentryJsBinding mockBinding;
      late SentryWeb sut;

      setUp(() {
        mockBinding = MockSentryJsBinding();
        sut = SentryWeb(mockBinding, options);
      });

      test(
        'captureStructuredEnvelope: exception thrown does not block sending the envelopes',
        () async {
          // disable so the test doesnt fail
          options.automatedTestMode = false;

          final attachmentHeader = SentryEnvelopeItemHeader('test');
          final attachment = SentryEnvelopeItem(
            attachmentHeader,
            () => throw Exception('throw'),
          );
          final event = SentryEnvelopeItem.fromEvent(SentryEvent());

          final header = SentryEnvelopeHeader(null, null);
          final envelope = SentryEnvelope(header, [attachment, event]);

          await sut.captureStructuredEnvelope(envelope);

          final verification = verify(mockBinding.captureEnvelope(captureAny));
          verification.called(1);

          final List<dynamic> capturedEnvelope =
              verification.captured.single as List<dynamic>;

          final envelopeItems = capturedEnvelope[1];
          expect(envelopeItems.length, 1);
        },
      );

      group('no-op or throwing methods', () {
        test('captureReplay throws unsupported error', () {
          expect(() => sut.captureReplay(), throwsUnsupportedError);
        });

        test('methods execute without calling JS binding', () {
          sut.addBreadcrumb(Breadcrumb());
          sut.captureEnvelope(Uint8List(0));
          sut.clearBreadcrumbs();
          sut.displayRefreshRate();
          sut.fetchNativeAppStart();
          sut.loadContexts();
          sut.nativeCrash();
          sut.removeContexts('key');
          sut.removeExtra('key');
          sut.removeTag('key');
          sut.resumeAppHangTracking();
          sut.pauseAppHangTracking();
          sut.setContexts('key', 'value');
          sut.setExtra('key', 'value');
          sut.setReplayConfig(
            ReplayConfig(windowWidth: 0, windowHeight: 0, width: 0, height: 0),
          );
          sut.setTag('key', 'value');
          sut.setUser(null);

          verifyZeroInteractions(mockBinding);
        });

        test('methods return expected default values', () {
          expect(sut.displayRefreshRate(), isNull);
          expect(sut.fetchNativeAppStart(), isNull);
          expect(sut.loadContexts(), isNull);
        });
      });

      test('payload uint8list: captures correct length', () async {
        final sdkVersion = SdkVersion(name: 'test', version: '1000');
        final event = SentryEvent();
        final attachment = SentryAttachment.fromByteData(ByteData(100), 'test');
        final envelope = SentryEnvelope.fromEvent(
          event,
          sdkVersion,
          attachments: [attachment],
        );

        await sut.captureStructuredEnvelope(envelope);

        final verification = verify(mockBinding.captureEnvelope(captureAny));
        verification.called(1);

        final List<dynamic> capturedEnvelope =
            verification.captured.single as List<dynamic>;

        final envelopeItems = capturedEnvelope[1];
        final envelopeAttachment = envelopeItems[1];
        final envelopeAttachmentHeader = envelopeAttachment.first;
        final envelopeAttachmentItem = envelopeAttachment[1];

        expect(envelopeAttachmentHeader['length'], 100);
        expect(envelopeAttachmentItem.length, 100);
      });

      test('payload json: captures correct length', () async {
        final sdkVersion = SdkVersion(name: 'test', version: '1000');
        final event = SentryEvent();
        final envelope = SentryEnvelope.fromEvent(event, sdkVersion);

        await sut.captureStructuredEnvelope(envelope);

        final verification = verify(mockBinding.captureEnvelope(captureAny));
        verification.called(1);

        final List<dynamic> capturedEnvelope =
            verification.captured.single as List<dynamic>;

        final envelopeItems = capturedEnvelope[1];
        final envelopeEvent = envelopeItems.first;
        final envelopeEventHeader = envelopeEvent.first;
        final envelopeEventItem = envelopeEvent[1];

        // ignore: invalid_use_of_internal_member
        final length = utf8JsonEncoder.convert(event.toJson()).length;
        final envelopeItemLength = envelopeEventItem.length;
        expect(envelopeEventHeader['length'], length);
        expect(envelopeItemLength, length);
      });
    });
  });
}

@JS('globalThis')
external JSObject get _globalThis;
