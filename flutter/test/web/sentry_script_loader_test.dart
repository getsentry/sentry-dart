@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/web/script_loader/script_dom_api.dart';
import 'package:sentry_flutter/src/web/script_loader/sentry_script_loader.dart';
import 'package:sentry_flutter/src/web/sentry_js_bundle.dart';

import '../mocks.dart';
import 'utils.dart';

// Just some random/arbitrary script that we can use for injecting
const randomWorkingScriptUrl =
    'https://cdn.jsdelivr.net/npm/random-js@2.1.0/dist/random-js.umd.min.js';

void main() {
  group('$SentryScriptLoader', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();

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
      await loadScript(randomWorkingScriptUrl, fixture.options);

      await sut.loadWebSdk(productionScripts);
      final scriptElements = fetchAllScripts();
      expect(scriptElements.first.src,
          endsWith('$jsSdkVersion/bundle.tracing.min.js'));
    });

    test('Closes and cleans up resources', () async {
      final sut = fixture.getSut();

      await loadScript(randomWorkingScriptUrl, fixture.options);

      await sut.loadWebSdk(debugScripts);

      final beforeCloseScripts = fetchAllScripts();
      expect(beforeCloseScripts.length, 2);

      await sut.close();

      final afterCloseScripts = fetchAllScripts();
      expect(afterCloseScripts.length,
          beforeCloseScripts.length - debugScripts.length);
    });
  });
}

class Fixture {
  final options = defaultTestOptions();

  SentryScriptLoader getSut() {
    return SentryScriptLoader(options: options);
  }
}
