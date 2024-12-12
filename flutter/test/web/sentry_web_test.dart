@TestOn('browser')
library flutter_test;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/web/script_loader/sentry_script_loader.dart';
import 'package:sentry_flutter/src/web/sentry_js_binding.dart';
import 'package:sentry_flutter/src/web/sentry_js_bundle.dart';
import 'package:sentry_flutter/src/web/sentry_web.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';
import 'utils.dart';

void main() {
  group('$SentryWeb', () {
    late SentryWeb sut;
    late SentryFlutterOptions options;
    late Hub hub;

    setUp(() async {
      hub = MockHub();
      options = defaultTestOptions();
      final loader = SentryScriptLoader(options);
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
    });

    test('options getter returns the original options', () {
      expect(sut.options, same(options));
    });

    test('native features are not supported', () {
      expect(sut.supportsCaptureEnvelope, isFalse);
      expect(sut.supportsLoadContexts, isFalse);
      expect(sut.supportsReplay, isFalse);
    });

    group('unsupported methods', () {
      test('addBreadcrumb throws', () {
        expect(() => sut.addBreadcrumb(Breadcrumb()), throwsUnsupportedError);
      });

      test('beginNativeFrames throws', () {
        expect(() => sut.beginNativeFrames(), throwsUnsupportedError);
      });

      test('captureEnvelope throws', () {
        expect(
          () => sut.captureEnvelope(Uint8List(0), false),
          throwsUnsupportedError,
        );
      });

      test('captureReplay throws', () {
        expect(() => sut.captureReplay(false), throwsUnsupportedError);
      });

      test('clearBreadcrumbs throws', () {
        expect(() => sut.clearBreadcrumbs(), throwsUnsupportedError);
      });

      test('collectProfile throws', () {
        expect(
          () => sut.collectProfile(SentryId.empty(), 0, 0),
          throwsUnsupportedError,
        );
      });

      test('discardProfiler throws', () {
        expect(
          () => sut.discardProfiler(SentryId.empty()),
          throwsUnsupportedError,
        );
      });

      test('displayRefreshRate throws', () {
        expect(() => sut.displayRefreshRate(), throwsUnsupportedError);
      });

      test('endNativeFrames throws', () {
        expect(
          () => sut.endNativeFrames(SentryId.empty()),
          throwsUnsupportedError,
        );
      });

      test('fetchNativeAppStart throws', () {
        expect(() => sut.fetchNativeAppStart(), throwsUnsupportedError);
      });

      test('loadContexts throws', () {
        expect(() => sut.loadContexts(), throwsUnsupportedError);
      });

      test('loadDebugImages throws', () {
        expect(
          () => sut.loadDebugImages(SentryStackTrace(frames: [])),
          throwsUnsupportedError,
        );
      });

      test('nativeCrash throws', () {
        expect(() => sut.nativeCrash(), throwsUnsupportedError);
      });

      test('setUser throws', () {
        expect(() => sut.setUser(null), throwsUnsupportedError);
      });

      test('startProfiler throws', () {
        expect(
            () => sut.startProfiler(SentryId.empty()), throwsUnsupportedError);
      });
    });
  });
}
