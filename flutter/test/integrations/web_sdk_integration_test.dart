@TestOn('browser')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/src/integrations/web_sdk_integration.dart';
import 'package:sentry_flutter/src/web/script_loader/sentry_script_loader.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  group('$WebSdkIntegration', () {
    late Fixture fixture;
    late WebSdkIntegration sut;

    setUp(() async {
      fixture = Fixture();
      sut = fixture.getSut();

      when(fixture.web.init(any)).thenReturn(null);
      when(fixture.web.close()).thenReturn(null);
    });

    test('adds integration', () async {
      await sut.call(fixture.hub, fixture.options);

      expect(fixture.options.sdk.integrations.contains(WebSdkIntegration.name),
          true);
    });

    test('loads scripts and initializes web', () async {
      await sut.call(fixture.hub, fixture.options);

      expect(fixture.scriptLoader.loadScriptsCalls, 1);
      verify(fixture.web.init(fixture.hub)).called(1);
    });

    test('closes resources', () async {
      await sut.close();

      expect(fixture.scriptLoader.closeCalls, 1);
      verify(fixture.web.close()).called(1);
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = defaultTestOptions();
  late FakeSentryScriptLoader scriptLoader;
  late MockSentryNativeBinding web;

  WebSdkIntegration getSut() {
    options.scriptLoader = FakeSentryScriptLoader(options);
    web = MockSentryNativeBinding();
    return WebSdkIntegration(web);
  }
}

class FakeSentryScriptLoader extends SentryScriptLoader {
  FakeSentryScriptLoader(super.options);

  int loadScriptsCalls = 0;
  int closeCalls = 0;

  @override
  Future<void> loadWebSdk(List<Map<String, String>> scripts,
      {String trustedTypePolicyName = defaultTrustedPolicyName}) {
    loadScriptsCalls += 1;

    return super
        .loadWebSdk(scripts, trustedTypePolicyName: trustedTypePolicyName);
  }

  @override
  Future<void> close() {
    closeCalls += 1;

    return super.close();
  }
}
