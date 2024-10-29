@TestOn('browser')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/web/sentry_script_loader.dart';
import 'dart:html';

import '../mocks.dart';

void main() {
  group('SentryScriptLoader', () {
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
  });
}

class Fixture {
  final SentryFlutterOptions options = defaultTestOptions();

  SentryScriptLoader getSut({bool debug = false}) {
    options.platformChecker = MockPlatformChecker(isDebug: debug);
    return SentryScriptLoader(options);
  }
}
