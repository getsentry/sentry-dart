library;

import 'package:sentry/sentry.dart';
import 'package:test/test.dart';
import 'package:sentry/src/feature_flags_integration.dart';
import 'package:sentry/src/sentry_tracer.dart';

import 'test_utils.dart';
import 'mocks/mock_hub.dart';

void main() {
  group('$FeatureFlagsIntegration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('adds itself to sdk.integrations', () {
      final sut = fixture.getSut();

      sut.call(fixture.hub, fixture.options);

      expect(
        fixture.options.sdk.integrations.contains('FeatureFlagsIntegration'),
        isTrue,
      );
    });

    test('adds feature flag to scope', () async {
      final sut = fixture.getSut();

      sut.call(fixture.hub, fixture.options);

      await sut.addFeatureFlag('foo', true);

      expect(fixture.hub.scope.contexts[SentryFeatureFlags.type], isNotNull);
      expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.first.flag,
        equals('foo'),
      );
      expect(
        fixture
            .hub.scope.contexts[SentryFeatureFlags.type]?.values.first.result,
        equals(true),
      );
    });

    test('replaces existing feature flag as newest', () async {
      final sut = fixture.getSut();

      sut.call(fixture.hub, fixture.options);

      await sut.addFeatureFlag('foo', true);
      await sut.addFeatureFlag('bar', true);
      await sut.addFeatureFlag('foo', false);

      final flags = fixture.hub.scope.contexts[SentryFeatureFlags.type]
          as SentryFeatureFlags;

      expect(flags.values.map((e) => e.flag), equals(['bar', 'foo']));
      expect(flags.values.last.result, equals(false));
    });

    test('updates existing feature flag without dropping oldest in full buffer',
        () async {
      final sut = fixture.getSut();

      sut.call(fixture.hub, fixture.options);

      for (var i = 0; i < 100; i++) {
        await sut.addFeatureFlag('foo_$i', i.isEven);
      }

      await sut.addFeatureFlag('foo_50', true);

      final flags = fixture.hub.scope.contexts[SentryFeatureFlags.type]
          as SentryFeatureFlags;

      expect(flags.values.length, equals(100));
      expect(flags.values.first.flag, equals('foo_0'));
      expect(flags.values.last.flag, equals('foo_50'));
      expect(flags.values.last.result, equals(true));
    });

    test('removes oldest feature flag only when adding over the limit',
        () async {
      final sut = fixture.getSut();

      sut.call(fixture.hub, fixture.options);

      for (var i = 0; i < 100; i++) {
        await sut.addFeatureFlag('foo_$i', i % 2 == 0 ? true : false);
      }

      expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.length,
        equals(100),
      );

      expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.first.flag,
        equals('foo_0'),
      );
      expect(
        fixture
            .hub.scope.contexts[SentryFeatureFlags.type]?.values.first.result,
        equals(true),
      );

      expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.last.flag,
        equals('foo_99'),
      );
      expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.last.result,
        equals(false),
      );

      await sut.addFeatureFlag('foo_100', true);

      expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.length,
        equals(100),
      );

      expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.first.flag,
        equals('foo_1'),
      );
      expect(
        fixture
            .hub.scope.contexts[SentryFeatureFlags.type]?.values.first.result,
        equals(false),
      );

      expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.last.flag,
        equals('foo_100'),
      );
      expect(
        fixture.hub.scope.contexts[SentryFeatureFlags.type]?.values.last.result,
        equals(true),
      );
    });

    test('keeps only the 100 most recent unique feature flags', () async {
      final sut = fixture.getSut();

      sut.call(fixture.hub, fixture.options);

      for (var i = 0; i < 105; i++) {
        await sut.addFeatureFlag('foo_$i', i.isEven);
      }

      final flags = fixture.hub.scope.contexts[SentryFeatureFlags.type]
          as SentryFeatureFlags;

      expect(flags.values.length, equals(100));
      expect(flags.values.first.flag, equals('foo_5'));
      expect(flags.values.last.flag, equals('foo_104'));
    });

    test('adds feature flag to active span', () async {
      final sut = fixture.getSut();
      final span = fixture.createSpan();
      fixture.hub.activeSpan = span;

      sut.call(fixture.hub, fixture.options);

      await sut.addFeatureFlag('checkout', true);

      expect(
        span.attributes['flag.evaluation.checkout']?.toJson(),
        equals({'value': true, 'type': 'boolean'}),
      );
    });

    test('does not add feature flag to static span when span v2 is active',
        () async {
      final sut = fixture.getSut();
      final span = fixture.createSpan();
      final staticSpan = fixture.createStaticSpan();
      fixture.hub.activeSpan = span;
      fixture.hub.legacySpan = staticSpan;

      sut.call(fixture.hub, fixture.options);

      await sut.addFeatureFlag('checkout', true);

      expect(
        span.attributes['flag.evaluation.checkout']?.toJson(),
        equals({'value': true, 'type': 'boolean'}),
      );
      expect(staticSpan.data, isNot(contains('flag.evaluation.checkout')));
      expect(fixture.hub.getSpanCalls, equals(0));
    });

    test('updates active span feature flag in place', () async {
      final sut = fixture.getSut();
      final span = fixture.createSpan();
      fixture.hub.activeSpan = span;

      sut.call(fixture.hub, fixture.options);

      await sut.addFeatureFlag('checkout', true);
      await sut.addFeatureFlag('checkout', false);

      expect(
        fixture.featureFlagAttributes(span),
        equals({
          'flag.evaluation.checkout': {'value': false, 'type': 'boolean'},
        }),
      );
    });

    test('adds at most 10 unique feature flags to active span', () async {
      final sut = fixture.getSut();
      final span = fixture.createSpan();
      fixture.hub.activeSpan = span;

      sut.call(fixture.hub, fixture.options);

      for (var i = 0; i < 11; i++) {
        await sut.addFeatureFlag('foo_$i', i.isEven);
      }

      expect(fixture.featureFlagAttributes(span).keys, hasLength(10));
      expect(span.attributes, isNot(contains('flag.evaluation.foo_10')));
    });

    test('updates existing active span feature flag after limit is reached',
        () async {
      final sut = fixture.getSut();
      final span = fixture.createSpan();
      fixture.hub.activeSpan = span;

      sut.call(fixture.hub, fixture.options);

      for (var i = 0; i < 10; i++) {
        await sut.addFeatureFlag('foo_$i', i.isEven);
      }
      await sut.addFeatureFlag('foo_5', true);

      expect(fixture.featureFlagAttributes(span).keys, hasLength(10));
      expect(
        span.attributes['flag.evaluation.foo_5']?.toJson(),
        equals({'value': true, 'type': 'boolean'}),
      );
    });

    test('adds feature flag to active static span', () async {
      final sut = fixture.getSut();
      final span = fixture.createStaticSpan();
      fixture.hub.legacySpan = span;

      sut.call(fixture.hub, fixture.options);

      await sut.addFeatureFlag('checkout', true);

      expect(span.data['flag.evaluation.checkout'], isTrue);
    });

    test('updates active static span feature flag in place', () async {
      final sut = fixture.getSut();
      final span = fixture.createStaticSpan();
      fixture.hub.legacySpan = span;

      sut.call(fixture.hub, fixture.options);

      await sut.addFeatureFlag('checkout', true);
      await sut.addFeatureFlag('checkout', false);

      expect(
        fixture.featureFlagData(span),
        equals({'flag.evaluation.checkout': false}),
      );
    });

    test('adds at most 10 unique feature flags to active static span',
        () async {
      final sut = fixture.getSut();
      final span = fixture.createStaticSpan();
      fixture.hub.legacySpan = span;

      sut.call(fixture.hub, fixture.options);

      for (var i = 0; i < 11; i++) {
        await sut.addFeatureFlag('foo_$i', i.isEven);
      }

      expect(fixture.featureFlagData(span).keys, hasLength(10));
      expect(span.data, isNot(contains('flag.evaluation.foo_10')));
    });

    test(
        'updates existing active static span feature flag after limit is reached',
        () async {
      final sut = fixture.getSut();
      final span = fixture.createStaticSpan();
      fixture.hub.legacySpan = span;

      sut.call(fixture.hub, fixture.options);

      for (var i = 0; i < 10; i++) {
        await sut.addFeatureFlag('foo_$i', i.isEven);
      }
      await sut.addFeatureFlag('foo_5', true);

      expect(fixture.featureFlagData(span).keys, hasLength(10));
      expect(span.data['flag.evaluation.foo_5'], isTrue);
    });

    test('does not add feature flag to ended active static span', () async {
      final sut = fixture.getSut();
      final span = fixture.createStaticSpan();
      await span.finish();
      fixture.hub.legacySpan = span;

      sut.call(fixture.hub, fixture.options);

      await sut.addFeatureFlag('foo', true);

      expect(span.data, isNot(contains('flag.evaluation.foo')));
    });

    test('adds feature flag only to scope when no active span exists',
        () async {
      final sut = fixture.getSut();

      sut.call(fixture.hub, fixture.options);

      await sut.addFeatureFlag('foo', true);

      final flags = fixture.hub.scope.contexts[SentryFeatureFlags.type]
          as SentryFeatureFlags;
      expect(flags.values.single.flag, equals('foo'));
      expect(fixture.hub.getActiveSpanCalls, equals(1));
      expect(fixture.hub.getSpanCalls, equals(1));
    });

    test('does not add feature flag to ended active span', () async {
      final sut = fixture.getSut();
      final span = fixture.createSpan();
      span.end();
      fixture.hub.activeSpan = span;

      sut.call(fixture.hub, fixture.options);

      await sut.addFeatureFlag('foo', true);

      expect(span.attributes, isNot(contains('flag.evaluation.foo')));
    });

    test('does not backfill existing scope flags into active span', () async {
      final sut = fixture.getSut();

      sut.call(fixture.hub, fixture.options);

      await sut.addFeatureFlag('old', true);
      final span = fixture.createSpan();
      fixture.hub.activeSpan = span;
      await sut.addFeatureFlag('new', true);

      expect(span.attributes, isNot(contains('flag.evaluation.old')));
      expect(
        span.attributes['flag.evaluation.new']?.toJson(),
        equals({'value': true, 'type': 'boolean'}),
      );
    });

    test('does not propagate active span feature flags to children', () async {
      final sut = fixture.getSut();
      final parent = fixture.createSpan();
      final child = fixture.createSpan(parentSpan: parent);

      sut.call(fixture.hub, fixture.options);

      fixture.hub.activeSpan = parent;
      await sut.addFeatureFlag('parent', true);
      fixture.hub.activeSpan = child;
      await sut.addFeatureFlag('child', true);

      expect(parent.attributes, isNot(contains('flag.evaluation.child')));
      expect(child.attributes, isNot(contains('flag.evaluation.parent')));
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = defaultTestOptions();

  FeatureFlagsIntegration getSut() {
    return FeatureFlagsIntegration();
  }

  SentryTracer createStaticSpan() {
    return SentryTracer(
      SentryTransactionContext('root', 'operation'),
      hub,
    );
  }

  RecordingSentrySpanV2 createSpan({RecordingSentrySpanV2? parentSpan}) {
    final dscCreator = (RecordingSentrySpanV2 span) =>
        SentryTraceContextHeader(SentryId.newId(), 'publicKey');

    if (parentSpan != null) {
      return RecordingSentrySpanV2.child(
        parent: parentSpan,
        name: 'child',
        onSpanEnd: (_) async {},
        clock: options.clock,
        dscCreator: dscCreator,
      );
    }

    return RecordingSentrySpanV2.root(
      name: 'root',
      traceId: SentryId.newId(),
      onSpanEnd: (_) async {},
      clock: options.clock,
      dscCreator: dscCreator,
      samplingDecision: SentryTracesSamplingDecision(true),
    );
  }

  Map<String, Map<String, dynamic>> featureFlagAttributes(
    RecordingSentrySpanV2 span,
  ) {
    return Map.fromEntries(
      span.attributes.entries
          .where((entry) => entry.key.startsWith('flag.evaluation.'))
          .map((entry) => MapEntry(entry.key, entry.value.toJson())),
    );
  }

  Map<String, dynamic> featureFlagData(SentryTracer span) {
    return Map.fromEntries(
      span.data.entries.where(
        (entry) => entry.key.startsWith('flag.evaluation.'),
      ),
    );
  }
}
