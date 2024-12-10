@TestOn('browser')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/web/script_loader/noop_script_dom_api.dart';
import 'package:sentry_flutter/src/web/script_loader/sentry_script_loader.dart';
import 'package:sentry_flutter/src/web/sentry_js_bundle.dart';

import '../mocks.dart';
import 'dom_api/script_dom_api.dart';

void main() {
  group('$SentryScriptLoader', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    tearDown(() {
      final existingScripts = fetchAllScripts();
      for (final script in existingScripts) {
        script.remove();
      }
    });

    // automatically tests TrustedType not configured as well
    test('Loads production scripts correctly', () async {
      final sut = fixture.getSut();

      await sut.loadWebSdk(productionScripts);

      final scripts = fetchAllScripts();
      expect(
          scripts.first.src, endsWith('$jsSdkVersion/bundle.tracing.min.js'));
    });

    test('Loads debug scripts correctly', () async {
      final sut = fixture.getSut();

      await sut.loadWebSdk(debugScripts);

      final scripts = fetchAllScripts();
      expect(scripts.first.src, endsWith('$jsSdkVersion/bundle.tracing.js'));
    });

    test('Does not load scripts twice', () async {
      final sut = fixture.getSut();

      await sut.loadWebSdk(productionScripts);

      final initialScriptCount = fetchAllScripts().length;

      await sut.loadWebSdk(productionScripts);
      expect(fetchAllScripts().length, initialScriptCount);
    });

    test('Handles script loading failures', () async {
      final failingScripts = [
        {
          'url': 'https://invalid',
        },
      ];
      final sut = fixture.getSut();

      // Modify script URL to cause failure
      expect(
          () async => await sut.loadWebSdk(failingScripts), throwsA(anything));

      // loading after the failure still works
      await sut.loadWebSdk(productionScripts);

      final scripts = fetchAllScripts();
      expect(
          scripts.first.src, endsWith('$jsSdkVersion/bundle.tracing.min.js'));
    });

    test('Handles script loading failures with automatedTestMode false',
        () async {
      fixture.options.automatedTestMode = false;
      final failingScripts = [
        {
          'url': 'https://invalid',
        },
      ];
      final sut = fixture.getSut();

      // Modify script URL to cause failure
      await sut.loadWebSdk(failingScripts);

      // loading after the failure still works
      await sut.loadWebSdk(productionScripts);

      final scripts = fetchAllScripts();
      expect(
          scripts.first.src, endsWith('$jsSdkVersion/bundle.tracing.min.js'));
    });

    test('Loads sentry script as first element', () async {
      final sut = fixture.getSut();

      // use loadScript since that disregards the isLoaded check
      await loadScript('https://google.com', fixture.options);

      await sut.loadWebSdk(productionScripts);
      final scriptElements = fetchAllScripts();
      expect(scriptElements.first.src,
          endsWith('$jsSdkVersion/bundle.tracing.min.js'));
    });
  });
}

class Fixture {
  final options = defaultTestOptions();

  SentryScriptLoader getSut() {
    return SentryScriptLoader(options);
  }
}
