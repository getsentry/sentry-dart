// ignore_for_file: invalid_use_of_internal_member

@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/native_session_integration.dart';
import 'package:sentry_flutter/src/native/sentry_native_binding.dart';

import '../mocks.dart';

void main() {
  group('$NativeSessionIntegration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('adds integration', () {
      fixture.registerIntegration();

      expect(
        fixture.options.sdk.integrations,
        contains(NativeSessionIntegration.integrationName),
      );
    });

    test('updates native session for sampled out unhandled event', () async {
      fixture.registerIntegration();

      await fixture.dispatchSampledOut(_event(handled: false));

      expect(fixture.binding.unhandledUpdates, [true]);
    });

    test('ignores sampled out handled event', () async {
      fixture.registerIntegration();

      await fixture.dispatchSampledOut(_event(handled: true));

      expect(fixture.binding.unhandledUpdates, isEmpty);
    });

    test('does not register when auto session tracking is disabled', () async {
      fixture.options.enableAutoSessionTracking = false;
      fixture.registerIntegration();

      await fixture.dispatchSampledOut(_event(handled: false));

      expect(fixture.binding.unhandledUpdates, isEmpty);
      expect(
        fixture.options.sdk.integrations,
        isNot(contains(NativeSessionIntegration.integrationName)),
      );
    });

    test('unregisters callback on close', () async {
      fixture.registerIntegration();
      fixture.sut.close();

      await fixture.dispatchSampledOut(_event(handled: false));

      expect(fixture.binding.unhandledUpdates, isEmpty);
    });

    test('does not surface native update errors', () async {
      fixture.binding.throwOnUpdate = true;
      fixture.registerIntegration();

      await expectLater(
        fixture.dispatchSampledOut(_event(handled: false)),
        completes,
      );
    });
  });
}

SentryEvent _event({required bool handled}) => SentryEvent(
  exceptions: [
    SentryException(
      type: 'StateError',
      value: 'failure',
      mechanism: Mechanism(type: 'FlutterError', handled: handled),
    ),
  ],
);

class Fixture {
  final options = defaultTestOptions(platform: MockPlatform.iOS());
  final binding = _FakeNativeBinding();
  late final hub = Hub(options);
  late final sut = NativeSessionIntegration(binding);

  void registerIntegration() {
    sut.call(hub, options);
  }

  Future<void> dispatchSampledOut(SentryEvent event) async {
    await options.lifecycleRegistry.dispatchCallback(
      OnEventSampledOut(event, Hint()),
    );
  }
}

class _FakeNativeBinding extends Fake implements SentryNativeBinding {
  final unhandledUpdates = <bool>[];
  bool throwOnUpdate = false;

  @override
  Future<void> updateSessionForDroppedEventNonTerminating(
    bool unhandled,
  ) async {
    unhandledUpdates.add(unhandled);
    if (throwOnUpdate) {
      throw Exception('native session update failed');
    }
  }
}
