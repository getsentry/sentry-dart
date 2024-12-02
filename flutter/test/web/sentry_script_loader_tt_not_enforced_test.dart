@TestOn('browser')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/web/script_loader/sentry_script_loader.dart';
import 'package:sentry_flutter/src/web/sentry_js_bundle.dart';

import '../mocks.dart';
import 'dom_api/html_script_dom_api.dart';

// The other TT tests will be split up into multiple files
// because TrustedTypes cannot be relaxed after they are set
// * sentry_script_loader_tt_not_enforced_test.dart : default TT configuration (not enforced)
// * sentry_script_loader_tt_custom_test.dart : TT are customized, but allowed
// * sentry_script_loader_tt_forbidden_test.dart: TT are completely disallowed

void main() {
  group('loadWebSdk (no TrustedTypes configured)', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('Injects script into document head', () async {
      final sut = fixture.getSut();

      await sut.loadWebSdk(productionScripts);

      final scripts = querySelectorAll('script');
      expect(
          scripts.first.src, contains('$jsSdkVersion/bundle.tracing.min.js'));
    });
  });
}

class Fixture {
  final options = defaultTestOptions();

  SentryScriptLoader getSut() {
    return SentryScriptLoader(options);
  }
}
