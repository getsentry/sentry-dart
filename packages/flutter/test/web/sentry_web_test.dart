@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:sentry/src/sentry_envelope_item_header.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/utils/data_normalizer.dart';
import 'package:sentry_flutter/src/replay/replay_config.dart';
import 'package:sentry_flutter/src/web/script_loader/sentry_script_loader.dart';
import 'package:sentry_flutter/src/web/sentry_js_binding.dart';
import 'package:sentry_flutter/src/web/sentry_js_bundle.dart';
import 'package:sentry_flutter/src/web/sentry_web.dart';

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
        expect(jsOptions['defaultIntegrations'][0].toString(),
            contains('name: GlobalHandlers'));
        expect(jsOptions['defaultIntegrations'][1].toString(),
            contains('name: Dedupe'));
      });

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

        await sut.captureStructuredEnvelope(SentryEnvelope.fromEvent(
            SentryEvent(), SdkVersion(name: 'test', version: '0')));
      });

      test('loadDebugImages returns null if no debug ids are available',
          () async {
        await sut.init(hub);
        _globalThis['_sentryDebugIds'] = null;

        final frames = [
          SentryStackFrame(absPath: 'http://127.0.0.1:8080/main.dart.js')
        ];
        final stackTrace = SentryStackTrace(frames: frames);
        final images = await sut.loadDebugImages(stackTrace);

        expect(images, isNull);
      });

      test('loadDebugImages returns null if no matching absPath or filename',
          () async {
        await sut.init(hub);
        _globalThis['_sentryDebugIds'] = debugIdMap.jsify();

        final frames = [SentryStackFrame(absPath: 'abc', fileName: 'def')];
        final stackTrace = SentryStackTrace(frames: frames);
        final images = await sut.loadDebugImages(stackTrace);

        expect(images, isNull);
      });

      test(
          'loadDebugImages loads debug id to debug images with matching absPath',
          () async {
        await sut.init(hub);
        _globalThis['_sentryDebugIds'] = debugIdMap.jsify();

        final frames = [
          SentryStackFrame(absPath: 'http://127.0.0.1:8080/main.dart.js')
        ];
        final stackTrace = SentryStackTrace(frames: frames);
        final images = await sut.loadDebugImages(stackTrace);

        expect(images, isNotNull);
        expect(images!.length, 1);
        expect(images.first.codeFile, frames.first.absPath);
        expect(images.first.debugId, debugId);
      });

      test(
          'loadDebugImages loads debug id to debug images with matching filename',
          () async {
        await sut.init(hub);
        _globalThis['_sentryDebugIds'] = debugIdMap.jsify();

        final frames = [
          SentryStackFrame(fileName: 'http://127.0.0.1:8080/main.dart.js')
        ];
        final stackTrace = SentryStackTrace(frames: frames);
        final images = await sut.loadDebugImages(stackTrace);

        expect(images, isNotNull);
        expect(images!.length, 1);
        expect(images.first.codeFile, frames.first.fileName);
        expect(images.first.debugId, debugId);
      });
    });

    group('with real replay binding', () {
      late SentryWeb sut;
      late SentryJsBinding binding;

      setUp(() async {
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
        options.replay.enableWebCanvasRecording = true;
        options.replay.sessionSampleRate = expectedSessionSampleRate;
        options.replay.onErrorSampleRate = expectedOnErrorSampleRate;

        await sut.init(hub);

        final jsOptions = binding.getJsOptions();
        final integrations = jsOptions['integrations'] as List<dynamic>;

        expect(
            jsOptions['replaysSessionSampleRate'], expectedSessionSampleRate);
        expect(
            jsOptions['replaysOnErrorSampleRate'], expectedOnErrorSampleRate);
        final integrationNames =
            integrations.map((integration) => integration.toString());
        expect(integrationNames, contains(contains('name: Replay')));
        expect(integrationNames, contains(contains('name: ReplayCanvas')));
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
            attachmentHeader, () => throw Exception('throw'));
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
      });

      group('no-op or throwing methods', () {
        test('captureReplay throws unsupported error', () {
          expect(() => sut.captureReplay(), throwsUnsupportedError);
        });

        test('methods execute without calling JS binding', () {
          sut.captureEnvelope(Uint8List(0), false);
          sut.collectProfile(SentryId.empty(), 0, 0);
          sut.discardProfiler(SentryId.empty());
          sut.displayRefreshRate();
          sut.fetchNativeAppStart();
          sut.loadContexts();
          sut.nativeCrash();
          sut.resumeAppHangTracking();
          sut.pauseAppHangTracking();
          sut.setReplayConfig(ReplayConfig(
              windowWidth: 0, windowHeight: 0, width: 0, height: 0));
          sut.startProfiler(SentryId.empty());

          verifyZeroInteractions(mockBinding);
        });

        test('methods return expected default values', () {
          expect(sut.displayRefreshRate(), isNull);
          expect(sut.fetchNativeAppStart(), isNull);
          expect(sut.loadContexts(), isNull);
          expect(sut.collectProfile(SentryId.empty(), 0, 0), isNull);
          expect(sut.startProfiler(SentryId.empty()), isNull);
        });
      });

      test('scope methods call JS binding with normalized payloads', () {
        final userObject = Object();
        final user = SentryUser(
          id: 'fixture-id',
          data: {'object': userObject},
        );
        sut.setUser(user);
        final userVerification = verify(mockBinding.setUser(captureAny));
        userVerification.called(1);
        expect(
          userVerification.captured.single,
          normalizeMap(user.toJson()),
        );

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

        final breadcrumbVerification =
            verify(mockBinding.addBreadcrumb(captureAny));
        breadcrumbVerification.called(2);
        expect(
          breadcrumbVerification.captured[0],
          {
            'timestamp': breadcrumb.timestamp.millisecondsSinceEpoch / 1000,
            'message': 'fixture-message',
            'data': normalizeMap(breadcrumb.data),
            if (breadcrumb.level != null) 'level': breadcrumb.level!.name,
          },
        );
        expect(
          breadcrumbVerification.captured[1],
          {
            'timestamp':
                userInteractionBreadcrumb.timestamp.millisecondsSinceEpoch /
                    1000,
            'category': 'ui.click',
            if (userInteractionBreadcrumb.level != null)
              'level': userInteractionBreadcrumb.level!.name,
            'type': 'user',
          },
        );

        final replayBreadcrumbVerification =
            verify(mockBinding.addReplayBreadcrumb(captureAny));
        replayBreadcrumbVerification.called(2);
        expect(
          replayBreadcrumbVerification.captured[0],
          {
            'timestamp': breadcrumb.timestamp.millisecondsSinceEpoch / 1000,
            'message': 'fixture-message',
            'data': normalizeMap(breadcrumb.data),
            if (breadcrumb.level != null) 'level': breadcrumb.level!.name,
            'category': 'default',
          },
        );
        expect(
          replayBreadcrumbVerification.captured[1],
          {
            'timestamp':
                userInteractionBreadcrumb.timestamp.millisecondsSinceEpoch /
                    1000,
            'category': 'flutter.ui.click',
            if (userInteractionBreadcrumb.level != null)
              'level': userInteractionBreadcrumb.level!.name,
            'type': 'user',
          },
        );

        sut.clearBreadcrumbs();
        verify(mockBinding.clearBreadcrumbs()).called(1);

        final contextValue = {'object': Object()};
        sut.setContexts('fixture-context', contextValue);
        final contextVerification =
            verify(mockBinding.setContext('fixture-context', captureAny));
        contextVerification.called(1);
        expect(contextVerification.captured.single, normalize(contextValue));

        sut.removeContexts('fixture-context');
        verify(mockBinding.removeContext('fixture-context')).called(1);

        final extraValue = {'object': Object()};
        sut.setExtra('fixture-extra', extraValue);
        final extraVerification =
            verify(mockBinding.setExtra('fixture-extra', captureAny));
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
        final envelope = SentryEnvelope.fromEvent(event, sdkVersion,
            attachments: [attachment]);

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
