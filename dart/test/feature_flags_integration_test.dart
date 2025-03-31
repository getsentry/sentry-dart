@TestOn('vm')
library;

import 'package:sentry/sentry.dart';
import 'package:test/test.dart';
import 'package:sentry/src/feature_flags_integration.dart';

import 'test_utils.dart';
import 'mocks/mock_hub.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('adds itself to sdk.integrations', () {
    final sut = fixture.getSut();

    sut.call(fixture.hub, fixture.options);

    expect(fixture.options.sdk.integrations.contains('featureFlagsIntegration'),
        isTrue);
  });

  test('adds feature flag to scope', () async {
    final sut = fixture.getSut();

    sut.call(fixture.hub, fixture.options);

    await sut.addFeatureFlag('foo', 'bar');

    expect(fixture.hub.scope.contexts[SentryFeatureFlags.type], isNotNull);
    expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.first.name,
        equals('foo'));
    expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.first.value,
        equals('bar'));
  });

  test('replaces existing feature flag', () async {
    final sut = fixture.getSut();

    sut.call(fixture.hub, fixture.options);

    await sut.addFeatureFlag('foo', 'bar');
    await sut.addFeatureFlag('foo', 'baz');

    expect(fixture.hub.scope.contexts[SentryFeatureFlags.type], isNotNull);
    expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.first.name,
        equals('foo'));
    expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.first.value,
        equals('baz'));
  });

  test('removes oldest feature flag when there are more than 100', () async {
    final sut = fixture.getSut();

    sut.call(fixture.hub, fixture.options);

    for (var i = 0; i < 100; i++) {
      await sut.addFeatureFlag('foo_$i', 'bar_$i');
    }

    expect(fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.length,
        equals(100));

    expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.first.name,
        equals('foo_0'));
    expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.first.value,
        equals('bar_0'));

    expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.last.name,
        equals('foo_99'));
    expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.last.value,
        equals('bar_99'));

    await sut.addFeatureFlag('foo_100', 'bar_100');

    expect(fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.length,
        equals(100));

    expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.first.name,
        equals('foo_1'));
    expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.first.value,
        equals('bar_1'));

    expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.last.name,
        equals('foo_100'));
    expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.last.value,
        equals('bar_100'));
  });
}

class Fixture {
  final hub = MockHub();
  final options = defaultTestOptions();

  FeatureFlagsIntegration getSut() {
    return FeatureFlagsIntegration();
  }
}
