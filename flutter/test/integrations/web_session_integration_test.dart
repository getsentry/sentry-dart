// ignore_for_file: invalid_use_of_internal_member

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/web_session_integration.dart';
import 'package:sentry_flutter/src/native/sentry_native_binding.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  late Fixture fixture;
  late SentryNativeBinding native;
  late Hub hub;

  setUp(() {
    fixture = Fixture();
    native = MockSentryNativeBinding();
    hub = Hub(fixture.options);
    fixture.options.platform = MockPlatform(isWeb: true);
  });

  group('$WebSessionIntegration', () {
    test('does not add integration when enableAutoSessionTracking is false',
        () async {
      fixture.options.enableAutoSessionTracking = false;

      final sut = fixture.getSut(native);
      sut.call(hub, fixture.options);

      expect(
          fixture.options.sdk.integrations
              .contains(WebSessionIntegration.integrationName),
          false);
    });

    test('does not add integration when not on web platform', () async {
      fixture.options.platform = MockPlatform(isWeb: false);

      final sut = fixture.getSut(native);
      sut.call(hub, fixture.options);

      expect(
          fixture.options.sdk.integrations
              .contains(WebSessionIntegration.integrationName),
          false);
    });

    test('adds integration when enabled is called', () {
      final sut = fixture.getSut(native);
      sut.call(hub, fixture.options);
      sut.enable();

      expect(
          fixture.options.sdk.integrations
              .contains(WebSessionIntegration.integrationName),
          true);
    });

    test('handles enable being called multiple times', () {
      expect(
          fixture.options.lifecycleRegistry.lifecycleCallbacks.values.flattened,
          isEmpty);

      final sut = fixture.getSut(native);
      sut.call(hub, fixture.options);
      sut.enable();
      sut.enable(); // Call enable a second time

      expect(
          fixture.options.sdk.integrations
              .where((integration) =>
                  integration == WebSessionIntegration.integrationName)
              .length,
          1);

      expect(
          fixture.options.lifecycleRegistry.lifecycleCallbacks.values.flattened
              .length,
          1);
    });

    test('adds onBeforeSendEventCallback when enabled', () {
      final sut = fixture.getSut(native);

      expect(
          fixture.options.lifecycleRegistry.lifecycleCallbacks.values.flattened,
          isEmpty);

      sut.call(hub, fixture.options);
      sut.enable();

      expect(
          fixture.options.lifecycleRegistry.lifecycleCallbacks.values.flattened,
          isNotEmpty);
    });

    test('removes onBeforeSendEventCallback on close', () {
      final sut = fixture.getSut(native);
      sut.call(hub, fixture.options);
      sut.enable();
      expect(
          fixture.options.lifecycleRegistry.lifecycleCallbacks.values.flattened,
          isNotEmpty);

      sut.close();

      expect(
          fixture.options.lifecycleRegistry.lifecycleCallbacks.values.flattened,
          isEmpty);
    });

    test('sets WebSessionHandler when enabled', () {
      final sut = fixture.getSut(native);
      expect(sut.webSessionHandler, isNull);
      sut.call(hub, fixture.options);
      sut.enable();

      expect(sut.webSessionHandler, isNotNull);
    });
  });
}

class Fixture {
  final options = defaultTestOptions();

  WebSessionIntegration getSut(SentryNativeBinding native) {
    return WebSessionIntegration(native);
  }
}
