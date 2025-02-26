@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:sentry/src/sentry_envelope_item_header.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/replay/replay_config.dart';
import 'package:sentry_flutter/src/web/script_loader/sentry_script_loader.dart';
import 'package:sentry_flutter/src/web/sentry_js_binding.dart';
import 'package:sentry_flutter/src/web/sentry_js_bundle.dart';
import 'package:sentry_flutter/src/web/sentry_web.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  group('$SentryWeb', () {
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
          expect(() => sut.captureReplay(false), throwsUnsupportedError);
        });

        test('methods execute without calling JS binding', () {
          sut.addBreadcrumb(Breadcrumb());
          sut.beginNativeFrames();
          sut.captureEnvelope(Uint8List(0), false);
          sut.clearBreadcrumbs();
          sut.collectProfile(SentryId.empty(), 0, 0);
          sut.discardProfiler(SentryId.empty());
          sut.displayRefreshRate();
          sut.endNativeFrames(SentryId.empty());
          sut.fetchNativeAppStart();
          sut.loadContexts();
          sut.loadDebugImages(SentryStackTrace(frames: []));
          sut.nativeCrash();
          sut.removeContexts('key');
          sut.removeExtra('key');
          sut.removeTag('key');
          sut.resumeAppHangTracking();
          sut.pauseAppHangTracking();
          sut.setContexts('key', 'value');
          sut.setExtra('key', 'value');
          sut.setReplayConfig(ReplayConfig(width: 0, height: 0, frameRate: 0));
          sut.setTag('key', 'value');
          sut.setUser(null);
          sut.startProfiler(SentryId.empty());

          verifyZeroInteractions(mockBinding);
        });

        test('methods return expected default values', () {
          expect(sut.displayRefreshRate(), isNull);
          expect(sut.fetchNativeAppStart(), isNull);
          expect(sut.loadContexts(), isNull);
          expect(sut.loadDebugImages(SentryStackTrace(frames: [])), isNull);
          expect(sut.collectProfile(SentryId.empty(), 0, 0), isNull);
          expect(sut.endNativeFrames(SentryId.empty()), isNull);
          expect(sut.startProfiler(SentryId.empty()), isNull);
        });
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
