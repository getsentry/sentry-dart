// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/src/telemetry/enricher/native_contexts_attributes_provider.dart';

import '../../mocks.mocks.dart';

void main() {
  group('NativeContextsTelemetryAttributesProvider', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('when native contexts are available', () {
      test('includes os.name attribute', () async {
        final nativeBinding = fixture.createNativeBinding(
          osName: 'iOS',
          osVersion: '16.0',
        );
        final provider = fixture.getSut(nativeBinding);

        final attributes = await provider.attributes(Object());

        expect(attributes['os.name']?.value, 'iOS');
      });

      test('includes os.version attribute', () async {
        final nativeBinding = fixture.createNativeBinding(
          osName: 'iOS',
          osVersion: '16.0',
        );
        final provider = fixture.getSut(nativeBinding);

        final attributes = await provider.attributes(Object());

        expect(attributes['os.version']?.value, '16.0');
      });

      test('includes device.brand attribute', () async {
        final nativeBinding = fixture.createNativeBinding(
          deviceBrand: 'Apple',
        );
        final provider = fixture.getSut(nativeBinding);

        final attributes = await provider.attributes(Object());

        expect(attributes['device.brand']?.value, 'Apple');
      });

      test('includes device.model attribute', () async {
        final nativeBinding = fixture.createNativeBinding(
          deviceModel: 'iPhone14,2',
        );
        final provider = fixture.getSut(nativeBinding);

        final attributes = await provider.attributes(Object());

        expect(attributes['device.model']?.value, 'iPhone14,2');
      });

      test('includes device.family attribute', () async {
        final nativeBinding = fixture.createNativeBinding(
          deviceFamily: 'iOS',
        );
        final provider = fixture.getSut(nativeBinding);

        final attributes = await provider.attributes(Object());

        expect(attributes['device.family']?.value, 'iOS');
      });

      test('includes all attributes when all are set', () async {
        final nativeBinding = fixture.createNativeBinding(
          osName: 'iOS',
          osVersion: '16.0',
          deviceBrand: 'Apple',
          deviceModel: 'iPhone14,2',
          deviceFamily: 'iOS',
        );
        final provider = fixture.getSut(nativeBinding);

        final attributes = await provider.attributes(Object());

        expect(attributes['os.name']?.value, 'iOS');
        expect(attributes['os.version']?.value, '16.0');
        expect(attributes['device.brand']?.value, 'Apple');
        expect(attributes['device.model']?.value, 'iPhone14,2');
        expect(attributes['device.family']?.value, 'iOS');
      });
    });

    test('when caching attributes loads from native binding on first call',
        () async {
      final nativeBinding = fixture.createNativeBinding(
        osName: 'iOS',
        osVersion: '16.0',
      );
      final provider = fixture.getSut(nativeBinding);

      await provider.attributes(Object());

      verify(nativeBinding.loadContexts()).called(1);
    });

    test(
        'when caching attributes returns cached attributes on subsequent calls',
        () async {
      final nativeBinding = fixture.createNativeBinding(
        osName: 'iOS',
        osVersion: '16.0',
      );
      final provider = fixture.getSut(nativeBinding);

      final attributes1 = await provider.attributes(Object());
      final attributes2 = await provider.attributes(Object());

      expect(identical(attributes1, attributes2), isTrue);
    });

    test(
        'when caching attributes does not call native binding again after caching',
        () async {
      final nativeBinding = fixture.createNativeBinding(
        osName: 'iOS',
        osVersion: '16.0',
      );
      final provider = fixture.getSut(nativeBinding);

      await provider.attributes(Object());
      await provider.attributes(Object());
      await provider.attributes(Object());

      verify(nativeBinding.loadContexts()).called(1);
    });

    test(
        'when native contexts are null returns empty map when loadContexts returns null',
        () async {
      final nativeBinding = fixture.createNativeBinding(returnNull: true);
      final provider = fixture.getSut(nativeBinding);

      final attributes = await provider.attributes(Object());

      expect(attributes, isEmpty);
    });

    test(
        'when native contexts are empty returns empty map when contexts map is empty',
        () async {
      final nativeBinding = fixture.createNativeBinding(emptyContexts: true);
      final provider = fixture.getSut(nativeBinding);

      final attributes = await provider.attributes(Object());

      expect(attributes, isEmpty);
    });

    test(
        'when native contexts have null values omits attributes for null context values',
        () async {
      final nativeBinding = fixture.createNativeBinding(
        osName: 'iOS',
        osVersion: null,
        deviceBrand: null,
        deviceModel: 'iPhone14,2',
        deviceFamily: null,
      );
      final provider = fixture.getSut(nativeBinding);

      final attributes = await provider.attributes(Object());

      expect(attributes['os.name']?.value, 'iOS');
      expect(attributes.containsKey('os.version'), isFalse);
      expect(attributes.containsKey('device.brand'), isFalse);
      expect(attributes['device.model']?.value, 'iPhone14,2');
      expect(attributes.containsKey('device.family'), isFalse);
    });
  });
}

class Fixture {
  NativeContextsTelemetryAttributesProvider getSut(
      MockSentryNativeBinding nativeBinding) {
    return NativeContextsTelemetryAttributesProvider(nativeBinding);
  }

  MockSentryNativeBinding createNativeBinding({
    String? osName,
    String? osVersion,
    String? deviceBrand,
    String? deviceModel,
    String? deviceFamily,
    bool returnNull = false,
    bool emptyContexts = false,
  }) {
    final binding = MockSentryNativeBinding();

    if (returnNull) {
      when(binding.loadContexts()).thenAnswer((_) async => null);
    } else if (emptyContexts) {
      when(binding.loadContexts()).thenAnswer((_) async => {});
    } else {
      final contexts = <String, dynamic>{};

      final contextsMap = <String, dynamic>{};

      if (osName != null || osVersion != null) {
        final os = <String, dynamic>{};
        if (osName != null) os['name'] = osName;
        if (osVersion != null) os['version'] = osVersion;
        contextsMap['os'] = os;
      }

      if (deviceBrand != null || deviceModel != null || deviceFamily != null) {
        final device = <String, dynamic>{};
        if (deviceBrand != null) device['brand'] = deviceBrand;
        if (deviceModel != null) device['model'] = deviceModel;
        if (deviceFamily != null) device['family'] = deviceFamily;
        contextsMap['device'] = device;
      }

      contexts['contexts'] = contextsMap;

      when(binding.loadContexts()).thenAnswer((_) async => contexts);
    }

    return binding;
  }
}
