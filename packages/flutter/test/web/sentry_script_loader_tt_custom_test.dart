@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/web/script_loader/sentry_script_loader.dart';
import 'package:sentry_flutter/src/web/sentry_js_bundle.dart';

import '../mocks.dart';
import 'utils.dart';

// The other TT tests will be split up into multiple files
// because TrustedTypes cannot be relaxed after they are set
// * sentry_script_loader_tt_custom_test.dart : TT are customized, but allowed
// * sentry_script_loader_tt_forbidden_test.dart: TT are completely disallowed
// tests inspired by https://pub.dev/packages/google_identity_services_web

void main() {
  group('loadWebSdk (TrustedTypes configured)', () {
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

    injectMetaTag(<String, String>{
      'http-equiv': 'Content-Security-Policy',
      'content': "trusted-types my-custom-policy-name 'allow-duplicates';",
    });

    test('Wrong policy name: does not inject script', () async {
      final sut = fixture.getSut();

      expect(() async {
        await sut.loadWebSdk(productionScripts);
      }, throwsA(isA<TrustedTypesException>()));

      final script = fetchAllScripts().where((element) =>
          element.src.contains('$jsSdkVersion/bundle.tracing.min.js'));
      expect(script, isEmpty);
    });

    test(
        'Wrong policy name: does not inject script with automatedTestMode false',
        () async {
      fixture.options.automatedTestMode = false;
      final sut = fixture.getSut();

      await sut.loadWebSdk(productionScripts);

      final script = fetchAllScripts().where((element) =>
          element.src.contains('$jsSdkVersion/bundle.tracing.min.js'));
      expect(script, isEmpty);
    });

    test('Correct policy name: Completes', () {
      final sut = fixture.getSut();

      final Future<void> done = sut.loadWebSdk(productionScripts,
          trustedTypePolicyName: 'my-custom-policy-name');
      expect(done, isA<Future<void>>());

      final scripts = fetchAllScripts();
      expect(
          scripts.first.src, endsWith('$jsSdkVersion/bundle.tracing.min.js'));
    });
  });
}

class Fixture {
  final options = defaultTestOptions();

  SentryScriptLoader getSut() {
    return SentryScriptLoader(options: options);
  }
}
