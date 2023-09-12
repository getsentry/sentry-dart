import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/file_system_transport.dart';
import 'package:sentry_flutter/src/native/native_scope_observer.dart';

void testTransport({
  required Transport transport,
  required bool hasFileSystemTransport,
}) {
  expect(
    transport is FileSystemTransport,
    hasFileSystemTransport,
    reason: '$FileSystemTransport was wrongly set',
  );
}

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
    expect(integrations, isNot(contains(type)));
  }
}

void testBefore({
  required List<Integration> integrations,
  required Type beforeIntegration,
  required Type afterIntegration,
}) {
  final beforeIndex = integrations
      .indexWhere((element) => element.runtimeType == beforeIntegration);
  final afterIndex = integrations
      .indexWhere((element) => element.runtimeType == afterIntegration);
  expect(beforeIndex < afterIndex, true);
}
