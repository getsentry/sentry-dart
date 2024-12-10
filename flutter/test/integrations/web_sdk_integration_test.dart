@TestOn('browser')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/integrations/web_sdk_integration.dart';
import 'package:sentry_flutter/src/web/script_loader/sentry_script_loader.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  group('$WebSdkIntegration', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
    });

    test('adds integration', () async {
      final sut = fixture.getSut();

      await sut.call(fixture.hub, fixture.options);

      expect(fixture.options.sdk.integrations.contains(WebSdkIntegration.name),
          true);
    });

    test('calls executes loads scripts', () async {
      final sut = fixture.getSut();

      await sut.call(fixture.hub, fixture.options);

      expect(fixture.scriptLoader.loadScriptsCalls, 1);
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = defaultTestOptions();
  late FakeSentryScriptLoader scriptLoader;

  WebSdkIntegration getSut() {
    scriptLoader = FakeSentryScriptLoader(options);
    return WebSdkIntegration(scriptLoader);
  }
}

class FakeSentryScriptLoader extends SentryScriptLoader {
  FakeSentryScriptLoader(super.options);

  int loadScriptsCalls = 0;

  @override
  Future<void> loadWebSdk(List<Map<String, String>> scripts,
      {String trustedTypePolicyName = defaultTrustedPolicyName}) {
    loadScriptsCalls += 1;

    return super
        .loadWebSdk(scripts, trustedTypePolicyName: trustedTypePolicyName);
  }
}
