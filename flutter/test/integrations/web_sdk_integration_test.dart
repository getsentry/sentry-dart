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

      sut.call(fixture.hub, fixture.options);

      expect(
          fixture.options.sdk.integrations
              .contains('nativeAppStartIntegration'),
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
    scriptLoader = FakeSentryScriptLoader();
    return WebSdkIntegration(scriptLoader);
  }
}

class FakeSentryScriptLoader extends SentryScriptLoader {
  int loadScriptsCalls = 0;

  @override
  Future<void> load() async {
    loadScriptsCalls += 1;
  }
}
