import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/native_scope_observer.dart';

void testScopeObserver(
    {required SentryFlutterOptions options,
    required bool expectedHasNativeScopeObserver}) {
  var actualHasNativeScopeObserver = false;
  for (final scopeObserver in options.scopeObservers) {
    if (scopeObserver.runtimeType == NativeScopeObserver) {
      actualHasNativeScopeObserver = true;
      break;
    }
  }
  expect(actualHasNativeScopeObserver, expectedHasNativeScopeObserver);
}

void testConfiguration({
  required Iterable<Integration> integrations,
  required Iterable<Type> shouldHaveIntegrations,
  required Iterable<Type> shouldNotHaveIntegrations,
  SentryFlutterOptions? options,
}) {
  final numberOfIntegrationsByType = <Type, int>{};
  for (var e in integrations) {
    numberOfIntegrationsByType[e.runtimeType] =
        numberOfIntegrationsByType[e.runtimeType] ?? 0 + 1;
  }

  for (final type in shouldHaveIntegrations) {
    expect(numberOfIntegrationsByType, containsPair(type, 1));
  }

  shouldNotHaveIntegrations = Set.of(shouldNotHaveIntegrations)
      .difference(Set.of(shouldHaveIntegrations));
  for (final type in shouldNotHaveIntegrations) {
    expect(integrations.any((i) => i.runtimeType == type), false);
  }

  Integration? nativeIntegration;
  Integration? loadDebugImagesIntegration;
  if (kIsWeb) {
    nativeIntegration = integrations.firstWhereOrNull(
        (x) => x.runtimeType.toString() == 'WebSdkIntegration');
    loadDebugImagesIntegration = integrations.firstWhereOrNull(
        (x) => x.runtimeType.toString() == 'LoadWebDebugImagesIntegration');
  } else {
    nativeIntegration = integrations.firstWhereOrNull(
        (x) => x.runtimeType.toString() == 'NativeSdkIntegration');
    loadDebugImagesIntegration = integrations.firstWhereOrNull(
        (x) => x.runtimeType.toString() == 'LoadNativeDebugImagesIntegration');
  }
  expect(loadDebugImagesIntegration, isNotNull);
  expect(nativeIntegration, isNotNull);
}

void testBefore({
  required List<Integration> integrations,
  required Type beforeIntegration,
  required Type afterIntegration,
}) {
  expect(integrations.indexOfType(beforeIntegration),
      lessThan(integrations.indexOfType(afterIntegration)));
}

extension ListExtension<T> on List<T> {
  int indexOfType(Type type) {
    final index = indexWhere((element) => element.runtimeType == type);
    expect(index, greaterThanOrEqualTo(0), reason: '$type not found in $this');
    return index;
  }

  int indexOfTypeString(String type) {
    final index =
        indexWhere((element) => element.runtimeType.toString() == type);
    expect(index, greaterThanOrEqualTo(0), reason: '$type not found in $this');
    return index;
  }
}
