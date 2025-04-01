import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_firebase/src/sentry_firebase_integration.dart';
import 'package:sentry/sentry.dart';

import 'package:mockito/mockito.dart';
import '../mocks/mocks.mocks.dart';

import 'package:firebase_remote_config/firebase_remote_config.dart';

void main() {
  late final Fixture fixture;

  givenRemoveConfigUpdate() {
    final update = RemoteConfigUpdate({'test'});
    when(fixture.mockFirebaseRemoteConfig.onConfigUpdated)
        .thenAnswer((_) => Stream.value(update));
    when(fixture.mockFirebaseRemoteConfig.getBool('test')).thenReturn(true);
  }

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

  test('adds integration to options', () async {
    givenRemoveConfigUpdate();

    final sut = await fixture.getSut({'test'});

    sut.call(fixture.hub, fixture.options);

    expect(
      fixture.options.sdk.integrations.contains('sentryFirebaseIntegration'),
      isTrue,
    );
  });

  test('does not add integration to options if no keys are provided', () async {
    givenRemoveConfigUpdate();

    final sut = await fixture.getSut({});

    sut.call(fixture.hub, fixture.options);

    expect(
      fixture.options.sdk.integrations.contains('sentryFirebaseIntegration'),
      isFalse,
    );
  });

  test('adds update to feature flags', () async {
    givenRemoveConfigUpdate();

    final sut = await fixture.getSut({'test'});
    sut.call(fixture.hub, fixture.options);
    await Future<void>.delayed(const Duration(
        milliseconds: 100)); // wait for the subscription to be called

    // ignore: invalid_use_of_internal_member
    final featureFlags = fixture.hub.scope.contexts[SentryFeatureFlags.type]
        as SentryFeatureFlags?;

    expect(featureFlags, isNotNull);
    expect(featureFlags?.values.first.name, 'test');
    expect(featureFlags?.values.first.value, true);
  });

  test('doesn`t add update to feature flags if key is not in the list',
      () async {
    givenRemoveConfigUpdate();

    final sut = await fixture.getSut({'test2'});
    sut.call(fixture.hub, fixture.options);
    await Future<void>.delayed(const Duration(
        milliseconds: 100)); // wait for the subscription to be called

    // ignore: invalid_use_of_internal_member
    final featureFlags = fixture.hub.scope.contexts[SentryFeatureFlags.type]
        as SentryFeatureFlags?;

    expect(featureFlags, isNull);
  });
}

class Fixture {
  late Hub hub;
  late SentryOptions options;

  final mockFirebaseRemoteConfig = MockFirebaseRemoteConfig();

  Future<SentryFirebaseIntegration> getSut(Set<String> keys) async {
    return SentryFirebaseIntegration(mockFirebaseRemoteConfig, keys);
  }
}
