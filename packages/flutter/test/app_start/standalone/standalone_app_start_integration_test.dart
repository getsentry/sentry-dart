// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/app_start/standalone/standalone_app_start_integration.dart';
import 'package:sentry_flutter/src/app_start/standalone/standalone_app_start_lifecycle.dart';

import '../../mocks.dart';

void main() {
  group('$StandaloneAppStartIntegration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('starts the standalone app-start lifecycle', () async {
      await fixture.getSut().call(fixture.hub, fixture.options);

      expect(fixture.lifecycle.startCalls, 1);
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

    test('does not start lifecycle when standalone tracing is disabled',
        () async {
      fixture.options.enableStandaloneAppStartTracing = false;

      await fixture.getSut().call(fixture.hub, fixture.options);

      expect(fixture.lifecycle.startCalls, 0);
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

    test('closes the standalone app-start lifecycle', () async {
      await fixture.getSut().close();

      expect(fixture.lifecycle.closeCalls, 1);
    });
  });
}

class Fixture {
  final lifecycle = FakeStandaloneAppStartLifecycle();
  late final options = defaultTestOptions()
    ..tracesSampleRate = 1.0
    ..enableStandaloneAppStartTracing = true;
  late final hub = Hub(options);

  StandaloneAppStartIntegration getSut() =>
      StandaloneAppStartIntegration(lifecycle);
}

final class FakeStandaloneAppStartLifecycle
    implements StandaloneAppStartLifecycle {
  int startCalls = 0;
  int closeCalls = 0;

  @override
  Future<void> start() async {
    startCalls++;
  }

  @override
  Future<void> close() async {
    closeCalls++;
  }
}
