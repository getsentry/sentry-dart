@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/envelope/sentry_envelope_header.dart';
import 'package:sentry/src/envelope/sentry_envelope_item_header.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/utils/data_normalizer.dart';
import 'package:sentry_flutter/src/replay/replay_config.dart';
import 'package:sentry_flutter/src/web/script_loader/sentry_script_loader.dart';
import 'package:sentry_flutter/src/web/sentry_js_binding.dart';
import 'package:sentry_flutter/src/web/sentry_js_bundle.dart';
import 'package:sentry_flutter/src/web/replay/web_replay_canvas_bridge.dart';
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
        expect(jsOptions['defaultIntegrations'].length, 3);
        expect(
          jsOptions['defaultIntegrations'][0].toString(),
          contains('name: GlobalHandlers'),
        );
        expect(
          jsOptions['defaultIntegrations'][1].toString(),
          contains('name: Dedupe'),
        );
        // Adds the User-Agent, from which Sentry derives browser and OS.
        expect(
          jsOptions['defaultIntegrations'][2].toString(),
          contains('name: HttpContext'),
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

      test('replay is supported when a replay sample rate is set', () {
        options.replay.onErrorSampleRate = 1.0;

        expect(sut.supportsReplay, isTrue);
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

      // The JS SDK's Replay turns a buffering replay into a session from this
      // hook, when an error carrying its replay ID is sent.
      test('reports sent events to the JS afterSendEvent hook', () async {
        await sut.init(hub);
        final sentEventIds = <String>[];
        final sent = Completer<void>();
        final client = (_globalThis['Sentry'] as JSObject).callMethod<JSObject>(
          'getClient'.toJS,
        );
        client.callMethod<JSAny?>(
          'on'.toJS,
          'afterSendEvent'.toJS,
          ((JSObject event, JSAny? response) {
            sentEventIds.add((event['event_id'] as JSString).toDart);
            if (!sent.isCompleted) sent.complete();
          }).toJS,
        );
        final event = SentryEvent();

        await sut.captureStructuredEnvelope(
          SentryEnvelope.fromEvent(
            event,
            SdkVersion(name: 'test', version: '0'),
          ),
        );
        await sent.future.timeout(const Duration(seconds: 10));

        expect(sentEventIds, [event.eventId.toString()]);
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

    group('with real replay binding', () {
      late SentryWeb sut;
      late SentryJsBinding binding;

      setUp(() async {
        // The JS SDK resumes a replay session stored by an earlier test on
        // this origin, in that test's recording mode -- a resumed `session`
        // replay makes stop() upload its last segment to the fake DSN.
        (_globalThis['sessionStorage'] as JSObject).callMethod<JSAny?>(
          'removeItem'.toJS,
          'sentryReplaySession'.toJS,
        );
        final loader = SentryScriptLoader(options: options);
        await loader.loadWebSdk(debugReplayScripts);
        binding = createJsBinding();
        sut = SentryWeb(binding, options);
      });

      tearDown(() async {
        await sut.close();
      });

      test('init maps replay options to JS SDK', () async {
        const expectedSessionSampleRate = 0.1;
        const expectedOnErrorSampleRate = 1.0;
        options.replay.sessionSampleRate = expectedSessionSampleRate;
        options.replay.onErrorSampleRate = expectedOnErrorSampleRate;

        await sut.init(hub);

        final jsOptions = binding.getJsOptions();
        final integrations = jsOptions['integrations'] as List<dynamic>;

        expect(
          jsOptions['replaysSessionSampleRate'],
          expectedSessionSampleRate,
        );
        expect(
          jsOptions['replaysOnErrorSampleRate'],
          expectedOnErrorSampleRate,
        );
        final integrationNames = integrations.map(
          // dartify() converts plain-object integrations, not class instances.
          (integration) => integration is Map
              ? integration['name']
              : ((integration as JSObject)['name'] as JSString).toDart,
        );
        expect(integrationNames, containsAll(['Replay', 'ReplayCanvas']));
      });

      test('stopReplay and startReplay control the JS replay', () async {
        // Buffer mode: stopping a session replay uploads its last segment,
        // which would make this test depend on the network.
        options.replay.onErrorSampleRate = 1.0;
        await sut.init(hub);
        expect(binding.getReplayId(), isNotNull);

        await sut.stopReplay();
        expect(binding.getReplayId(), isNull);

        await sut.startReplay();
        expect(binding.getReplayId(), isNotNull);
      });

      test('flushReplay starts a stopped JS replay', () async {
        // Buffer mode: stopping a session replay uploads its last segment,
        // which would make this test depend on the network.
        options.replay.onErrorSampleRate = 1.0;
        await sut.init(hub);
        await sut.stopReplay();

        await sut.flushReplay();

        expect(binding.getReplayId(), isNotNull);
      });
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

          final verification = verify(
            mockBinding.captureEnvelope(captureAny, any),
          );
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
          sut.captureEnvelope(Uint8List(0));
          sut.displayRefreshRate();
          sut.fetchNativeAppStart();
          sut.loadContexts();
          sut.nativeCrash();
          sut.resumeAppHangTracking();
          sut.pauseAppHangTracking();
          sut.setReplayConfig(
            ReplayConfig(windowWidth: 0, windowHeight: 0, width: 0, height: 0),
          );

          verifyZeroInteractions(mockBinding);
        });

        test('methods return expected default values', () {
          expect(sut.displayRefreshRate(), isNull);
          expect(sut.fetchNativeAppStart(), isNull);
          expect(sut.loadContexts(), isNull);
        });
      });

      group('with replay enabled', () {
        late _FakeWebReplayCanvasBridge bridge;
        late List<String> calls;

        final config = ReplayConfig(
          windowWidth: 100,
          windowHeight: 100,
          width: 100,
          height: 100,
        );

        setUp(() async {
          calls = [];
          bridge = _FakeWebReplayCanvasBridge(calls);
          TestWidgetsFlutterBinding.ensureInitialized();
          options.bindingUtils = TestBindingWrapper();
          options.replay.onErrorSampleRate = 1.0;
          when(mockBinding.init(any)).thenReturn(null);
          when(mockBinding.close()).thenAnswer((_) => calls.add('jsClose'));
          when(
            mockBinding.startReplay(),
          ).thenAnswer((_) => calls.add('jsStart'));
          when(
            mockBinding.startReplayBuffering(),
          ).thenAnswer((_) => calls.add('jsStartBuffering'));
          when(mockBinding.stopReplay()).thenAnswer((_) async {
            calls.add('jsStop');
          });
          when(mockBinding.flushReplay()).thenAnswer((_) async {
            calls.add('jsFlush');
          });
          when(
            mockBinding.createManualReplayCanvasIntegration(),
          ).thenReturn(JSObject());
          sut = SentryWeb(
            mockBinding,
            options,
            createReplayCanvasBridge: (_) => bridge,
          );
          await sut.init(hub);
        });

        // Tests start the recorder, whose scheduler would keep capturing.
        tearDown(() async {
          await sut.close();
        });

        test(
          'close stops the replay bridge before closing the JS SDK',
          () async {
            await sut.setReplayConfig(config);

            await sut.close();

            expect(calls, ['bridgeStart', 'bridgeStop', 'jsClose']);
          },
        );

        test(
          'close closes the JS SDK even if stopping the recorder fails',
          () async {
            options.automatedTestMode = false;
            await sut.setReplayConfig(config);
            bridge.throwOnStop = true;

            await sut.close();

            expect(calls, ['bridgeStart', 'jsClose']);
          },
        );

        test('setReplayConfig retries starting after a failed start', () async {
          options.automatedTestMode = false;
          bridge.throwOnNextStart = true;

          await sut.setReplayConfig(config);
          await sut.setReplayConfig(config);

          expect(bridge.startCalls, 2);
        });

        test('stopReplay stops the recorder before the JS replay', () async {
          await sut.setReplayConfig(config);

          await sut.stopReplay();

          expect(calls, ['bridgeStart', 'bridgeStop', 'jsStop']);
        });

        test(
          'stopReplay stops the JS replay even if stopping the recorder fails',
          () async {
            options.automatedTestMode = false;
            await sut.setReplayConfig(config);
            bridge.throwOnStop = true;

            await sut.stopReplay();

            expect(calls, ['bridgeStart', 'jsStop']);
          },
        );

        test(
          'startReplay restarts the recorder after stopping it failed',
          () async {
            options.automatedTestMode = false;
            await sut.setReplayConfig(config);
            bridge.throwOnStop = true;
            await sut.stopReplay();
            bridge.throwOnStop = false;
            calls.clear();

            await sut.startReplay();

            expect(calls, ['jsStart', 'bridgeStart']);
          },
        );

        // ReplayIntegration doesn't await setReplayConfig, so a stop can
        // land while the recorder is still starting.
        test('stopReplay stops a recorder that is still starting', () async {
          final configured = sut.setReplayConfig(config);
          while (!calls.contains('bridgeStart')) {
            await Future<void>.microtask(() {});
          }

          await sut.stopReplay();
          await configured;

          expect(calls, ['bridgeStart', 'jsStop', 'bridgeStop']);
        });

        test('setReplayConfig does not restart a stopped recorder', () async {
          await sut.setReplayConfig(config);
          await sut.stopReplay();

          await sut.setReplayConfig(config);

          expect(bridge.startCalls, 1);
        });

        test('startReplay starts the JS replay and the recorder', () async {
          await sut.setReplayConfig(config);
          await sut.stopReplay();
          calls.clear();

          await sut.startReplay();

          expect(calls, ['jsStart', 'bridgeStart']);
        });

        test(
          'startReplayBuffering starts the JS replay buffering and the recorder',
          () async {
            await sut.setReplayConfig(config);
            await sut.stopReplay();
            calls.clear();

            await sut.startReplayBuffering();

            expect(calls, ['jsStartBuffering', 'bridgeStart']);
          },
        );

        test('flushReplay flushes the JS replay', () async {
          await sut.setReplayConfig(config);

          await sut.flushReplay();

          expect(calls, ['bridgeStart', 'jsFlush']);
        });

        test('flushReplay restarts a stopped recorder', () async {
          await sut.setReplayConfig(config);
          await sut.stopReplay();
          calls.clear();

          await sut.flushReplay();

          expect(calls, ['jsFlush', 'bridgeStart']);
        });

        test('startReplay does not restart a running recorder', () async {
          await sut.setReplayConfig(config);

          await sut.startReplay();

          expect(bridge.startCalls, 1);
        });
      });

      test('replay controls do not call JS when replay is disabled', () async {
        when(mockBinding.init(any)).thenReturn(null);
        await sut.init(hub);

        await sut.startReplay();
        await sut.startReplayBuffering();
        await sut.stopReplay();
        await sut.flushReplay();

        verifyNever(mockBinding.startReplay());
        verifyNever(mockBinding.startReplayBuffering());
        verifyNever(mockBinding.stopReplay());
        verifyNever(mockBinding.flushReplay());
      });

      group('replay click breadcrumb message', () {
        Map<String, dynamic> replayBreadcrumbFor(Breadcrumb breadcrumb) {
          sut.addBreadcrumb(breadcrumb);
          return verify(
                mockBinding.addReplayBreadcrumb(captureAny),
              ).captured.single
              as Map<String, dynamic>;
        }

        test('uses the view class', () {
          final replayBreadcrumb = replayBreadcrumbFor(
            Breadcrumb.userInteraction(
              subCategory: 'click',
              viewClass: 'InkWell',
            ),
          );

          expect(replayBreadcrumb['message'], 'InkWell');
        });

        test('prefers the view id over the view class', () {
          final replayBreadcrumb = replayBreadcrumbFor(
            Breadcrumb.userInteraction(
              subCategory: 'click',
              viewId: 'login_button',
              viewClass: 'ElevatedButton',
            ),
          );

          expect(replayBreadcrumb['message'], 'login_button');
        });

        // The label is text that the replay video masks.
        test('does not use the label', () {
          final replayBreadcrumb = replayBreadcrumbFor(
            Breadcrumb.userInteraction(
              subCategory: 'click',
              data: {'label': 'secret label'},
            ),
          );

          expect(replayBreadcrumb.containsKey('message'), isFalse);
        });

        test('keeps an existing message', () {
          final replayBreadcrumb = replayBreadcrumbFor(
            Breadcrumb.userInteraction(
              subCategory: 'click',
              message: 'custom',
              viewClass: 'InkWell',
            ),
          );

          expect(replayBreadcrumb['message'], 'custom');
        });
      });

      // Labels are widget text that the replay video masks.
      group('replay click breadcrumb data', () {
        Map<String, dynamic> replayBreadcrumbDataFor(Breadcrumb breadcrumb) {
          sut.addBreadcrumb(breadcrumb);
          final captured =
              verify(
                    mockBinding.addReplayBreadcrumb(captureAny),
                  ).captured.single
                  as Map<String, dynamic>;
          return captured['data'] as Map<String, dynamic>;
        }

        test('drops the label', () {
          final data = replayBreadcrumbDataFor(
            Breadcrumb.userInteraction(
              subCategory: 'click',
              viewId: 'login_button',
              data: {'label': 'secret label'},
            ),
          );

          expect(data.containsKey('label'), isFalse);
          expect(data['view.id'], 'login_button');
        });

        test('drops the labels in the touch path', () {
          final data = replayBreadcrumbDataFor(
            Breadcrumb.userInteraction(
              subCategory: 'click',
              data: {
                'path': [
                  {'element': 'ElevatedButton', 'label': 'secret label'},
                  {'name': 'form', 'element': 'Column'},
                ],
              },
            ),
          );

          expect(data['path'], [
            {'element': 'ElevatedButton'},
            {'name': 'form', 'element': 'Column'},
          ]);
        });

        test('does not drop the label from the event breadcrumb', () {
          sut.addBreadcrumb(
            Breadcrumb.userInteraction(
              subCategory: 'click',
              data: {'label': 'secret label'},
            ),
          );

          final captured =
              verify(mockBinding.addBreadcrumb(captureAny)).captured.single
                  as Map<String, dynamic>;
          expect((captured['data'] as Map)['label'], 'secret label');
        });
      });

      test('scope methods do not throw when the JS binding throws', () {
        options.automatedTestMode = false;
        final error = Exception('js failure');
        when(mockBinding.setUser(any)).thenThrow(error);
        when(mockBinding.addBreadcrumb(any)).thenThrow(error);
        when(mockBinding.addReplayBreadcrumb(any)).thenThrow(error);
        when(mockBinding.clearBreadcrumbs()).thenThrow(error);
        when(mockBinding.setContext(any, any)).thenThrow(error);
        when(mockBinding.removeContext(any)).thenThrow(error);
        when(mockBinding.setExtra(any, any)).thenThrow(error);
        when(mockBinding.removeExtra(any)).thenThrow(error);
        when(mockBinding.setTag(any, any)).thenThrow(error);
        when(mockBinding.removeTag(any)).thenThrow(error);

        expect(
          () => sut.setUser(SentryUser(id: 'fixture-id')),
          returnsNormally,
        );
        expect(() => sut.addBreadcrumb(Breadcrumb()), returnsNormally);
        expect(() => sut.clearBreadcrumbs(), returnsNormally);
        expect(() => sut.setContexts('key', 'value'), returnsNormally);
        expect(() => sut.removeContexts('key'), returnsNormally);
        expect(() => sut.setExtra('key', 'value'), returnsNormally);
        expect(() => sut.removeExtra('key'), returnsNormally);
        expect(() => sut.setTag('key', 'value'), returnsNormally);
        expect(() => sut.removeTag('key'), returnsNormally);
      });

      test('scope methods call JS binding with normalized payloads', () {
        final userObject = Object();
        final user = SentryUser(id: 'fixture-id', data: {'object': userObject});
        sut.setUser(user);
        final userVerification = verify(mockBinding.setUser(captureAny));
        userVerification.called(1);
        expect(userVerification.captured.single, normalizeMap(user.toJson()));

        sut.setUser(null);
        verify(mockBinding.setUser(null)).called(1);

        final breadcrumbObject = Object();
        final breadcrumb = Breadcrumb(
          message: 'fixture-message',
          data: {'object': breadcrumbObject},
          timestamp: DateTime.utc(2026, 1, 1),
        );
        sut.addBreadcrumb(breadcrumb);

        final userInteractionBreadcrumb = Breadcrumb.userInteraction(
          subCategory: 'click',
          timestamp: DateTime.utc(2026, 1, 2),
        );
        sut.addBreadcrumb(userInteractionBreadcrumb);

        final breadcrumbVerification = verify(
          mockBinding.addBreadcrumb(captureAny),
        );
        breadcrumbVerification.called(2);
        expect(breadcrumbVerification.captured[0], {
          'timestamp': breadcrumb.timestamp.millisecondsSinceEpoch / 1000,
          'message': 'fixture-message',
          'data': normalizeMap(breadcrumb.data),
          if (breadcrumb.level != null) 'level': breadcrumb.level!.name,
        });
        expect(breadcrumbVerification.captured[1], {
          'timestamp':
              userInteractionBreadcrumb.timestamp.millisecondsSinceEpoch / 1000,
          'category': 'ui.click',
          if (userInteractionBreadcrumb.level != null)
            'level': userInteractionBreadcrumb.level!.name,
          'type': 'user',
        });

        final replayBreadcrumbVerification = verify(
          mockBinding.addReplayBreadcrumb(captureAny),
        );
        replayBreadcrumbVerification.called(2);
        expect(replayBreadcrumbVerification.captured[0], {
          'timestamp': breadcrumb.timestamp.millisecondsSinceEpoch / 1000,
          'message': 'fixture-message',
          'data': normalizeMap(breadcrumb.data),
          if (breadcrumb.level != null) 'level': breadcrumb.level!.name,
          'category': 'default',
        });
        expect(replayBreadcrumbVerification.captured[1], {
          'timestamp':
              userInteractionBreadcrumb.timestamp.millisecondsSinceEpoch / 1000,
          'category': 'flutter.ui.click',
          if (userInteractionBreadcrumb.level != null)
            'level': userInteractionBreadcrumb.level!.name,
          'type': 'user',
        });

        sut.clearBreadcrumbs();
        verify(mockBinding.clearBreadcrumbs()).called(1);

        final contextValue = {'object': Object()};
        sut.setContexts('fixture-context', contextValue);
        final contextVerification = verify(
          mockBinding.setContext('fixture-context', captureAny),
        );
        contextVerification.called(1);
        expect(contextVerification.captured.single, normalize(contextValue));

        sut.removeContexts('fixture-context');
        verify(mockBinding.removeContext('fixture-context')).called(1);

        final extraValue = {'object': Object()};
        sut.setExtra('fixture-extra', extraValue);
        final extraVerification = verify(
          mockBinding.setExtra('fixture-extra', captureAny),
        );
        extraVerification.called(1);
        expect(extraVerification.captured.single, normalize(extraValue));

        sut.removeExtra('fixture-extra');
        verify(mockBinding.removeExtra('fixture-extra')).called(1);

        sut.setTag('fixture-tag', 'fixture-value');
        verify(mockBinding.setTag('fixture-tag', 'fixture-value')).called(1);

        sut.removeTag('fixture-tag');
        verify(mockBinding.removeTag('fixture-tag')).called(1);
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

        final verification = verify(
          mockBinding.captureEnvelope(captureAny, any),
        );
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

      test('passes the envelope events to the binding', () async {
        final event = SentryEvent(tags: {'replayId': 'fixture-replay-id'});
        final envelope = SentryEnvelope.fromEvent(
          event,
          SdkVersion(name: 'test', version: '1000'),
        );

        await sut.captureStructuredEnvelope(envelope);

        final events =
            verify(mockBinding.captureEnvelope(any, captureAny)).captured.single
                as List<Map<String, dynamic>>;
        expect(events, hasLength(1));
        expect(events.single['event_id'], event.eventId.toString());
        expect(events.single['tags'], {'replayId': 'fixture-replay-id'});
      });

      test('passes no events for an envelope without events', () async {
        final attachment = SentryEnvelopeItem.fromAttachment(
          SentryAttachment.fromByteData(ByteData(10), 'test'),
        );
        final envelope = SentryEnvelope(SentryEnvelopeHeader(null, null), [
          attachment,
        ]);

        await sut.captureStructuredEnvelope(envelope);

        final events = verify(
          mockBinding.captureEnvelope(any, captureAny),
        ).captured.single;
        expect(events, isEmpty);
      });

      test('payload json: captures correct length', () async {
        final sdkVersion = SdkVersion(name: 'test', version: '1000');
        final event = SentryEvent();
        final envelope = SentryEnvelope.fromEvent(event, sdkVersion);

        await sut.captureStructuredEnvelope(envelope);

        final verification = verify(
          mockBinding.captureEnvelope(captureAny, any),
        );
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

class _FakeWebReplayCanvasBridge implements WebReplayCanvasBridge {
  _FakeWebReplayCanvasBridge(this.calls);

  final List<String> calls;
  int startCalls = 0;
  bool throwOnNextStart = false;
  bool throwOnStop = false;

  @override
  void start() {
    startCalls++;
    if (throwOnNextStart) {
      throwOnNextStart = false;
      throw StateError('bridge failed to start');
    }
    calls.add('bridgeStart');
  }

  @override
  void updatePosition(Rect rect, double devicePixelRatio) {}

  @override
  void feedFrame(Uint8List rgba, int width, int height) {}

  @override
  void stop() {
    if (throwOnStop) throw StateError('bridge failed to stop');
    calls.add('bridgeStop');
  }
}
