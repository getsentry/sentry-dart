// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/telemetry/enricher/native_contexts_attributes_provider.dart';

import '../../mocks.mocks.dart';

void main() {
  group('$NativeContextsTelemetryAttributesProvider', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test(
        'when native contexts are available includes all attributes when all are set',
        () async {
      final nativeBinding = fixture.createNativeBinding(
        osName: 'iOS',
        osVersion: '16.0',
        deviceBrand: 'Apple',
        deviceModel: 'iPhone14,2',
        deviceFamily: 'iOS',
      );
      final provider = fixture.getSut(nativeBinding);

      final attributes = await provider.attributes(Object());

      expect(attributes[SemanticAttributesConstants.osName]?.value, 'iOS');
      expect(attributes[SemanticAttributesConstants.osVersion]?.value, '16.0');
      expect(
          attributes[SemanticAttributesConstants.deviceBrand]?.value, 'Apple');
      expect(attributes[SemanticAttributesConstants.deviceModel]?.value,
          'iPhone14,2');
      expect(
          attributes[SemanticAttributesConstants.deviceFamily]?.value, 'iOS');
    });

    test('attributes are cached and reused', () async {
      final nativeBinding = fixture.createNativeBinding(
        osName: 'iOS',
        osVersion: '16.0',
      );
      final provider = fixture.getSut(nativeBinding);

      final attributes1 = await provider.attributes(Object());
      final attributes2 = await provider.attributes(Object());
      final attributes3 = await provider.attributes(Object());

      expect(identical(attributes1, attributes2), isTrue);
      expect(identical(attributes2, attributes3), isTrue);
      verify(nativeBinding.loadContexts()).called(1);
    });

    test('when native contexts are null or empty returns an empty map',
        () async {
      final nativeBindings = [
        fixture.createNativeBinding(returnNull: true),
        fixture.createNativeBinding(emptyContexts: true),
      ];

      for (final nativeBinding in nativeBindings) {
        final provider = fixture.getSut(nativeBinding);
        final attributes = await provider.attributes(Object());
        expect(attributes, isEmpty);
      }
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

      expect(attributes[SemanticAttributesConstants.osName]?.value, 'iOS');
      expect(attributes.containsKey(SemanticAttributesConstants.osVersion),
          isFalse);
      expect(attributes.containsKey(SemanticAttributesConstants.deviceBrand),
          isFalse);
      expect(attributes[SemanticAttributesConstants.deviceModel]?.value,
          'iPhone14,2');
      expect(attributes.containsKey(SemanticAttributesConstants.deviceFamily),
          isFalse);
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
