@TestOn('browser')
library flutter_test;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/web/sentry_js_binding.dart';
import 'package:sentry_flutter/src/web/sentry_web.dart';

void main() {
  group('$SentryWeb', () {
    late SentryWeb sut;
    late SentryFlutterOptions options;

    setUp(() {
      options = SentryFlutterOptions(dsn: 'https://key@sentry.io/123');
      final binding = createJsBinding();
      sut = SentryWeb(binding, options);
    });

    tearDown(() async {
      await sut.close();
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
