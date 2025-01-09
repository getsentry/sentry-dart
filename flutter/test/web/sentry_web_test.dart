@TestOn('browser')
library flutter_test;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/replay/replay_config.dart';
import 'package:sentry_flutter/src/web/script_loader/sentry_script_loader.dart';
import 'package:sentry_flutter/src/web/sentry_js_binding.dart';
import 'package:sentry_flutter/src/web/sentry_js_bundle.dart';
import 'package:sentry_flutter/src/web/sentry_web.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';
import 'utils.dart';

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

      setUp(() async {
        final loader = SentryScriptLoader(options: options);
        await loader.loadWebSdk(debugScripts);
        final binding = createJsBinding();
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

        // quick check that it doesn't work before init
        expect(() => getJsOptions()['dsn'], throwsA(anything));

        await sut.init(hub);

        final jsOptions = getJsOptions();
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
        expect(sut.supportsCaptureEnvelope, isFalse);
        expect(sut.supportsLoadContexts, isFalse);
        expect(sut.supportsReplay, isFalse);
      });
    });

    group('no-op or throwing methods', () {
      late MockSentryJsBinding mockBinding;
      late SentryWeb sut;

      setUp(() {
        mockBinding = MockSentryJsBinding();
        sut = SentryWeb(mockBinding, options);
      });

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
        sut.setReplayConfig(
            ReplayConfig(width: 0, height: 0, frameRate: 0, bitRate: 0));
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
  });
}
