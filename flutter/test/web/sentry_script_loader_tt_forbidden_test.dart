@TestOn('browser')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/web/script_loader/sentry_script_loader.dart';
import 'package:sentry_flutter/src/web/sentry_js_bundle.dart';

import '../mocks.dart';
import 'dom_api/script_dom_api.dart';

// The other TT tests will be split up into multiple files
// because TrustedTypes cannot be relaxed after they are set
// * sentry_script_loader_test.dart : default TT configuration (not enforced)
// * sentry_script_loader_tt_custom_test.dart : TT are customized, but allowed
// * sentry_script_loader_tt_forbidden_test.dart: TT are completely disallowed

void main() {
  group('loadWebSdk (TrustedTypes forbidden)', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    injectMetaTag(<String, String>{
      'http-equiv': 'Content-Security-Policy',
      'content': "trusted-types 'none';",
    });

    test('Fail with TrustedTypesException', () {
      expect(() async {
        final sut = fixture.getSut();

        await sut.loadWebSdk(productionScripts);
      }, throwsA(isA<TrustedTypesException>()));
    });
  });
}

class Fixture {
  final options = defaultTestOptions();

  SentryScriptLoader getSut() {
    return SentryScriptLoader(options);
  }
}
