@TestOn('browser')
library flutter_test;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/integrations/web_sdk_integration.dart';
import 'package:sentry_flutter/src/web/script_loader/sentry_script_loader.dart';
import 'package:sentry_flutter/src/web/sentry_web.dart';

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

    test('calls executes web init', () async {
      final sut = fixture.getSut();

      await sut.call(fixture.hub, fixture.options);

      expect(fixture.web.initCalls, 1);
    });

    test('close executes web close', () async {
      final sut = fixture.getSut();

      await sut.call(fixture.hub, fixture.options);

      expect(fixture.web.closeCalls, 1);
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = defaultTestOptions();
  late FakeSentryScriptLoader scriptLoader;
  late FakeSentryWeb web;

  WebSdkIntegration getSut() {
    scriptLoader = FakeSentryScriptLoader(options);
    web = FakeSentryWeb();
    return WebSdkIntegration(web, scriptLoader);
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

class FakeSentryWeb implements SentryWebBinding {
  int initCalls = 0;
  int closeCalls = 0;

  @override
  FutureOr<void> init() {
    initCalls += 1;
  }

  @override
  FutureOr<void> close() {
    closeCalls += 1;
  }
}
