@TestOn('browser')
library flutter_test;

import 'dart:html';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/web/sentry_script_loader.dart';

import '../mocks.dart';

void main() {
  group('$SentryScriptLoader', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    tearDown(() {
      final existingScripts =
          document.querySelectorAll('script[src*="sentry-cdn"]');
      for (final script in existingScripts) {
        script.remove();
      }
    });

    test('loads production scripts by default', () async {
      final sut = fixture.getSut();

      await sut.loadScripts();

      final scripts = document.querySelectorAll('script[src*="sentry-cdn"]');
      for (final script in scripts) {
        final element = script as ScriptElement;
        expect(element.src, contains('.min.js'));
      }
    });

    test('loads debug scripts when debug is enabled', () async {
      final sut = fixture.getSut(debug: true);

      await sut.loadScripts();

      final scripts = document.querySelectorAll('script[src*="sentry-cdn"]');
      for (final script in scripts) {
        final element = script as ScriptElement;
        expect(element.src, isNot(contains('.min.js')));
      }
    });

    test('does not load scripts twice', () async {
      final sut = fixture.getSut();

      await sut.loadScripts();
      final initialScriptCount = document.querySelectorAll('script').length;

      await sut.loadScripts();
      expect(document.querySelectorAll('script').length, initialScriptCount);
    });

    test('handles script loading failures', () async {
      final scripts = [
        {
          'url': 'https://invalid',
        },
      ];

      // Modify script URL to cause failure
      final sut = fixture.getSut(scripts: scripts);

      await expectLater(() async {
        await sut.loadScripts();
      }, throwsA(anything));
    });

    test('maintains script loading order', () async {
      final sut = fixture.getSut();

      await sut.loadScripts();

      final scripts = document
          .querySelectorAll('script[src*="sentry-cdn"]')
          .map((s) => (s as ScriptElement).src)
          .toList();
      expect(scripts[0], contains('bundle.tracing.replay'));
      expect(scripts[1], contains('replay-canvas'));
    });
  });
}

class Fixture {
  final SentryFlutterOptions options = defaultTestOptions();

  SentryScriptLoader getSut(
      {bool debug = false, List<Map<String, String>>? scripts}) {
    options.platformChecker = MockPlatformChecker(isDebug: debug);
    return SentryScriptLoader(options, scripts: scripts);
  }
}
