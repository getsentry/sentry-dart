// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/app_start/standalone/standalone_app_start_integration.dart';
import 'package:sentry_flutter/src/app_start/standalone/standalone_app_start_handler.dart';

import '../../mocks.dart';

void main() {
  group('$StandaloneAppStartIntegration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('starts the standalone app-start handler', () async {
      await fixture.getSut().call(fixture.hub, fixture.options);

      expect(fixture.handler.startCalls, 1);
    });

    test('adds integration to sdk metadata', () async {
      await fixture.getSut().call(fixture.hub, fixture.options);

      expect(fixture.options.sdk.integrations, contains('StandaloneAppStart'));
    });

    test('adds standalone app-start tracing feature to sdk metadata', () async {
      await fixture.getSut().call(fixture.hub, fixture.options);

      expect(
        fixture.options.sdk.features,
        contains(SentryFeatures.standaloneAppStartTracing),
      );
    });

    test('does not start the handler when standalone tracing is disabled',
        () async {
      fixture.options.enableStandaloneAppStartTracing = false;

      await fixture.getSut().call(fixture.hub, fixture.options);

      expect(fixture.handler.startCalls, 0);
    });

    test(
        'does not add standalone app-start tracing feature when standalone tracing is disabled',
        () async {
      fixture.options.enableStandaloneAppStartTracing = false;

      await fixture.getSut().call(fixture.hub, fixture.options);

      expect(
        fixture.options.sdk.features,
        isNot(contains(SentryFeatures.standaloneAppStartTracing)),
      );
    });

    test('does not start the handler on an unsupported platform', () async {
      fixture.options.platform = MockPlatform.macOS();

      await fixture.getSut().call(fixture.hub, fixture.options);

      expect(fixture.handler.startCalls, 0);
    });

    test(
        'does not add standalone app-start tracing feature when tracing is disabled',
        () async {
      fixture.options.tracesSampleRate = null;
      fixture.options.tracesSampler = null;

      await fixture.getSut().call(fixture.hub, fixture.options);

      expect(
        fixture.options.sdk.features,
        isNot(contains(SentryFeatures.standaloneAppStartTracing)),
      );
    });

    test('does not let a failing handler escape into the integration chain',
        () async {
      fixture.options.automatedTestMode = false;
      fixture.handler.startError = StateError('handler blew up');

      await expectLater(
        fixture.getSut().call(fixture.hub, fixture.options),
        completes,
      );
    });

    test('rethrows a failing handler under automatedTestMode', () async {
      fixture.handler.startError = StateError('handler blew up');

      await expectLater(
        fixture.getSut().call(fixture.hub, fixture.options),
        throwsStateError,
      );
    });

    test('closes the standalone app-start handler', () async {
      await fixture.getSut().close();

      expect(fixture.handler.closeCalls, 1);
    });
  });
}

class Fixture {
  final handler = FakeStandaloneAppStartHandler();
  late final options = defaultTestOptions(platform: MockPlatform.iOS())
    ..tracesSampleRate = 1.0
    ..enableStandaloneAppStartTracing = true;
  late final hub = Hub(options);

  StandaloneAppStartIntegration getSut() =>
      StandaloneAppStartIntegration(handler);
}

final class FakeStandaloneAppStartHandler implements StandaloneAppStartHandler {
  int startCalls = 0;
  int closeCalls = 0;
  Object? startError;

  @override
  Future<void> start(SentryFlutterOptions options) async {
    startCalls++;
    final error = startError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> close() async {
    closeCalls++;
  }
}
