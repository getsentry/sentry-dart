import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/integrations/flutter_framework_feature_flag_integration.dart';

void main() {
  group(FlutterFrameworkFeatureFlagIntegration, () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();

      await Sentry.init((options) {
        options.dsn = 'https://example.com/sentry-dsn';
      });

      // ignore: invalid_use_of_internal_member
      fixture.hub = Sentry.currentHub;
      // ignore: invalid_use_of_internal_member
      fixture.options = fixture.hub.options;
    });

    tearDown(() {
      Sentry.close();
    });

    test('adds sdk integration', () {
      final sut = fixture.getSut('foo,bar,baz');
      sut.call(fixture.hub, fixture.options);

      expect(
          fixture.options.sdk.integrations
              .contains('FlutterFrameworkFeatureFlag'),
          true);
    });

    test('adds feature flags', () {
      final sut = fixture.getSut('foo,bar,baz');
      sut.call(fixture.hub, fixture.options);

      // ignore: invalid_use_of_internal_member
      final featureFlags = fixture.hub.scope.contexts[SentryFeatureFlags.type]
          as SentryFeatureFlags?;

      expect(featureFlags, isNotNull);
      expect(featureFlags?.values.length, 3);
      expect(featureFlags?.values.first.flag, 'flutter:foo');
      expect(featureFlags?.values.first.result, true);
      expect(featureFlags?.values[1].flag, 'flutter:bar');
      expect(featureFlags?.values[1].result, true);
      expect(featureFlags?.values[2].flag, 'flutter:baz');
      expect(featureFlags?.values[2].result, true);
    });

    test('skips empty', () {
      final sut = fixture.getSut('foo,,bar');
      sut.call(fixture.hub, fixture.options);

      // ignore: invalid_use_of_internal_member
      final featureFlags = fixture.hub.scope.contexts[SentryFeatureFlags.type]
          as SentryFeatureFlags?;

      expect(featureFlags, isNotNull);
      expect(featureFlags?.values.length, 2);
      expect(featureFlags?.values.first.flag, 'flutter:foo');
      expect(featureFlags?.values.first.result, true);
      expect(featureFlags?.values[1].flag, 'flutter:bar');
      expect(featureFlags?.values[1].result, true);
    });

    test('skips empty variant', () {
      final sut = fixture.getSut(',');
      sut.call(fixture.hub, fixture.options);

      // ignore: invalid_use_of_internal_member
      final featureFlags = fixture.hub.scope.contexts[SentryFeatureFlags.type]
          as SentryFeatureFlags?;

      expect(featureFlags, isNull);
    });

    test('prettifies', () {
      final sut = fixture.getSut('foo, bar');
      sut.call(fixture.hub, fixture.options);

      // ignore: invalid_use_of_internal_member
      final featureFlags = fixture.hub.scope.contexts[SentryFeatureFlags.type]
          as SentryFeatureFlags?;

      expect(featureFlags, isNotNull);
      expect(featureFlags?.values.length, 2);
      expect(featureFlags?.values.first.flag, 'flutter:foo');
      expect(featureFlags?.values.first.result, true);
      expect(featureFlags?.values[1].flag, 'flutter:bar');
      expect(featureFlags?.values[1].result, true);
    });
  });
}

class Fixture {
  late Hub hub;
  late SentryOptions options;

  FlutterFrameworkFeatureFlagIntegration getSut(String features) {
    return FlutterFrameworkFeatureFlagIntegration(flags: features);
  }
}
