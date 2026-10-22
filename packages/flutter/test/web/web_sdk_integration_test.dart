@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry_flutter/src/renderer/renderer.dart';
import 'package:sentry_flutter/src/web/web_sdk_integration.dart';
import 'package:sentry_flutter/src/web/script_loader/sentry_script_loader.dart';
import 'package:sentry_flutter/src/web/sentry_js_bundle.dart';

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
      when(fixture.web.supportsCaptureEnvelope).thenReturn(true);
    });

    group('enabled', () {
      setUp(() {
        fixture.options.autoInitializeNativeSdk = true;
      });

      test('adds integration', () async {
        await sut.call(fixture.hub, fixture.options);

        expect(
          fixture.options.sdk.integrations.contains(WebSdkIntegration.name),
          true,
        );
      });

      test('loads scripts and initializes web', () async {
        await sut.call(fixture.hub, fixture.options);

        expect(fixture.scriptLoader.loadScriptsCalls, 1);
        expect(fixture.scriptLoader.loadedScripts, same(debugScripts));
        verify(fixture.web.init(fixture.hub)).called(1);
      });

      test('loads replay scripts when replay is enabled', () async {
        fixture.useCanvasKitRenderer();
        fixture.options.replay.sessionSampleRate = 1.0;

        await sut.call(fixture.hub, fixture.options);

        expect(fixture.scriptLoader.loadScriptsCalls, 1);
        expect(fixture.scriptLoader.loadedScripts, same(debugReplayScripts));
        verify(fixture.web.init(fixture.hub)).called(1);
      });

      // SentryWeb only records with a renderer it can capture from.
      test(
        'loads the scripts without replay when the renderer is unsupported',
        () async {
          fixture.options.replay.sessionSampleRate = 1.0;
          fixture.options.platform = MockPlatform(isWeb: true);
          fixture.options.rendererWrapper = MockRendererWrapper(
            FlutterRenderer.html,
          );

          await sut.call(fixture.hub, fixture.options);

          expect(fixture.scriptLoader.loadedScripts, same(debugScripts));
        },
      );

      test('loads production scripts in release mode', () async {
        fixture.options.runtimeChecker = MockRuntimeChecker(
          buildMode: MockRuntimeCheckerBuildMode.release,
        );

        await sut.call(fixture.hub, fixture.options);

        expect(fixture.scriptLoader.loadedScripts, same(productionScripts));
      });

      test(
        'loads production replay scripts in release mode when replay is enabled',
        () async {
          fixture.useCanvasKitRenderer();
          fixture.options.runtimeChecker = MockRuntimeChecker(
            buildMode: MockRuntimeCheckerBuildMode.release,
          );
          fixture.options.replay.sessionSampleRate = 1.0;

          await sut.call(fixture.hub, fixture.options);

          expect(
            fixture.scriptLoader.loadedScripts,
            same(productionReplayScripts),
          );
        },
      );
    });

    group('disabled scenarios', () {
      final disabledScenarios = [
        _TestScenario('with autoInitializeNativeSdk=false', () {
          fixture.options.autoInitializeNativeSdk = false;
        }),
      ];

      for (final scenario in disabledScenarios) {
        group(scenario.description, () {
          setUp(scenario.setup);

          test('does not add integration', () async {
            await sut.call(fixture.hub, fixture.options);
            expect(
              fixture.options.sdk.integrations,
              isNot(contains(WebSdkIntegration.name)),
            );
          });

          test('does not load scripts and initialize web', () async {
            await sut.call(fixture.hub, fixture.options);
            expect(fixture.scriptLoader.loadScriptsCalls, 0);
            verifyNever(fixture.web.init(fixture.hub));
          });
        });
      }
    });

    test('closes resources', () async {
      await sut.close();

      expect(fixture.scriptLoader.closeCalls, 1);
      verify(fixture.web.close()).called(1);
    });
  });
}

class _TestScenario {
  final String description;
  final dynamic Function() setup;

  _TestScenario(this.description, this.setup);
}

class Fixture {
  final hub = MockHub();
  final options = defaultTestOptions();
  late FakeSentryScriptLoader scriptLoader;
  late MockSentryNativeBinding web;

  WebSdkIntegration getSut() {
    scriptLoader = FakeSentryScriptLoader(options: options);
    web = MockSentryNativeBinding();
    return WebSdkIntegration(web, scriptLoader);
  }

  // Replay scripts load only with a renderer replay can capture from, so
  // don't depend on the renderer the tests run with.
  void useCanvasKitRenderer() {
    options.platform = MockPlatform(isWeb: true);
    options.rendererWrapper = MockRendererWrapper(FlutterRenderer.canvasKit);
  }
}

class FakeSentryScriptLoader extends SentryScriptLoader {
  FakeSentryScriptLoader({super.options});

  int loadScriptsCalls = 0;
  int closeCalls = 0;
  List<Map<String, String>>? loadedScripts;

  @override
  Future<void> loadWebSdk(
    List<Map<String, String>> scripts, {
    String trustedTypePolicyName = defaultTrustedPolicyName,
  }) {
    loadScriptsCalls += 1;
    loadedScripts = scripts;

    return super.loadWebSdk(
      scripts,
      trustedTypePolicyName: trustedTypePolicyName,
    );
  }

  @override
  Future<void> close() {
    closeCalls += 1;

    return super.close();
  }
}
