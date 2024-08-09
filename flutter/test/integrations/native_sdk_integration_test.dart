@TestOn('vm')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/native_sdk_integration.dart';

import '../mocks.mocks.dart';
import 'fixture.dart';

void main() {
  group(NativeSdkIntegration, () {
    late IntegrationTestFixture<NativeSdkIntegration> fixture;

    setUp(() {
      fixture = IntegrationTestFixture(NativeSdkIntegration.new);
    });

    test('adds integration', () async {
      await fixture.registerIntegration();
      expect(
          fixture.options.sdk.integrations, contains('nativeSdkIntegration'));
      verify(fixture.binding.init(any)).called(1);
    });

    test('do not throw', () async {
      fixture.sut = NativeSdkIntegration(_ThrowingMockSentryNative());
      await fixture.registerIntegration();
      expect(fixture.options.sdk.integrations.contains('nativeSdkIntegration'),
          false);
    });

    test('closes native SDK', () async {
      await fixture.registerIntegration();
      await fixture.sut.close();
      verify(fixture.binding.close()).called(1);
    });

    test('does not call native sdk when auto init disabled', () async {
      fixture.options.autoInitializeNativeSdk = false;
      await fixture.registerIntegration();
      verifyNever(fixture.binding.init(any));
    });

    test('does not close native when auto init disabled', () async {
      fixture.options.autoInitializeNativeSdk = false;
      await fixture.registerIntegration();
      await fixture.sut.close();
      verifyNever(fixture.binding.close());
    });

    test(' is not added in case of an exception', () async {
      fixture.sut = NativeSdkIntegration(_ThrowingMockSentryNative());
      await fixture.registerIntegration();
      expect(fixture.options.sdk.integrations, <String>[]);
    });
  });
}

class _ThrowingMockSentryNative extends MockSentryNativeBinding {
  @override
  Future<void> init(Hub? hub) async {
    throw Exception();
  }
}
