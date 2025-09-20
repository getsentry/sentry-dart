import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_firebase_remote_config/sentry_firebase_remote_config.dart';

import '../mocks/mocks.mocks.dart';

void main() {
  late Fixture fixture;

  void mockGetAll(Fixture fixture) {
    when(fixture.mockFirebaseRemoteConfig.getAll()).thenReturn({
      'test':
          RemoteConfigValue([102, 97, 108, 115, 101], ValueSource.valueDefault),
      'foo': RemoteConfigValue(null, ValueSource.valueDefault),
    });
  }

  givenDefaultRemoteConfig() {
    when(fixture.mockFirebaseRemoteConfig.onConfigUpdated)
        .thenAnswer((_) => Stream.empty());

    mockGetAll(fixture);
    when(fixture.mockFirebaseRemoteConfig.getString('test'))
        .thenReturn('false');
    when(fixture.mockFirebaseRemoteConfig.getString('foo')).thenReturn('');
    when(fixture.mockFirebaseRemoteConfig.activate())
        .thenAnswer((_) => Future.value(true));
  }

  givenRemoteConfigUpdate() {
    final update = RemoteConfigUpdate({'test', 'foo'});
    when(fixture.mockFirebaseRemoteConfig.onConfigUpdated)
        .thenAnswer((_) => Stream.value(update));

    mockGetAll(fixture);
    when(fixture.mockFirebaseRemoteConfig.getString('test')).thenReturn('true');
    when(fixture.mockFirebaseRemoteConfig.getString('foo')).thenReturn('bar');
    when(fixture.mockFirebaseRemoteConfig.activate())
        .thenAnswer((_) => Future.value(true));
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
    givenDefaultRemoteConfig();

    final sut = await fixture.getSut();

    sut.call(fixture.hub, fixture.options);

    expect(
      fixture.options.sdk.integrations
          .contains('SentryFirebaseRemoteConfigIntegration'),
      isTrue,
    );
  });

  test('adds boolean default to feature flags', () async {
    givenDefaultRemoteConfig();

    final sut = await fixture.getSut();
    sut.call(fixture.hub, fixture.options);

    // ignore: invalid_use_of_internal_member
    final featureFlags = fixture.hub.scope.contexts[SentryFeatureFlags.type]
        as SentryFeatureFlags?;

    expect(featureFlags, isNotNull);
    expect(featureFlags?.values.length, 1);
    expect(featureFlags?.values.first.flag, 'firebase:test');
    expect(featureFlags?.values.first.result, isFalse);
  });

  test('adds boolean update to feature flags', () async {
    givenRemoteConfigUpdate();

    final sut = await fixture.getSut();
    sut.call(fixture.hub, fixture.options);
    await Future<void>.delayed(
      const Duration(
        milliseconds: 100,
      ),
    ); // wait for the subscription to be called

    // ignore: invalid_use_of_internal_member
    final featureFlags = fixture.hub.scope.contexts[SentryFeatureFlags.type]
        as SentryFeatureFlags?;

    expect(featureFlags, isNotNull);
    expect(featureFlags?.values.length, 1);
    expect(featureFlags?.values.first.flag, 'firebase:test');
    expect(featureFlags?.values.first.result, true);
  });

  test('stream canceled on close', () async {
    givenRemoteConfigUpdate();

    final streamSubscription = MockStreamSubscription<RemoteConfigUpdate>();
    when(streamSubscription.cancel()).thenAnswer((_) => Future.value());

    final stream = MockStream<RemoteConfigUpdate>();
    when(stream.listen(any)).thenAnswer((_) => streamSubscription);

    when(fixture.mockFirebaseRemoteConfig.onConfigUpdated)
        .thenAnswer((_) => stream);

    final sut = await fixture.getSut();
    await sut.call(fixture.hub, fixture.options);
    await sut.close();

    verify(streamSubscription.cancel()).called(1);
  });

  test('activate called by default', () async {
    givenRemoteConfigUpdate();

    final sut = await fixture.getSut();
    sut.call(fixture.hub, fixture.options);
    await Future<void>.delayed(
      const Duration(
        milliseconds: 100,
      ),
    );

    verify(fixture.mockFirebaseRemoteConfig.activate()).called(1);
  });

  test('activate not called if activateOnConfigUpdated is false', () async {
    givenRemoteConfigUpdate();

    final sut = await fixture.getSut(activateOnConfigUpdated: false);
    sut.call(fixture.hub, fixture.options);
    await Future<void>.delayed(
      const Duration(
        milliseconds: 100,
      ),
    );

    verifyNever(fixture.mockFirebaseRemoteConfig.activate());
  });

  test('activate called if activateOnConfigUpdated is true', () async {
    givenRemoteConfigUpdate();

    final sut = await fixture.getSut(activateOnConfigUpdated: true);
    sut.call(fixture.hub, fixture.options);
    await Future<void>.delayed(
      const Duration(
        milliseconds: 100,
      ),
    );

    verify(fixture.mockFirebaseRemoteConfig.activate()).called(1);
  });
}

class Fixture {
  late Hub hub;
  late SentryOptions options;

  final mockFirebaseRemoteConfig = MockFirebaseRemoteConfig();

  Future<SentryFirebaseRemoteConfigIntegration> getSut({
    bool? activateOnConfigUpdated,
  }) async {
    if (activateOnConfigUpdated == null) {
      return SentryFirebaseRemoteConfigIntegration(
        firebaseRemoteConfig: mockFirebaseRemoteConfig,
      );
    } else {
      return SentryFirebaseRemoteConfigIntegration(
        firebaseRemoteConfig: mockFirebaseRemoteConfig,
        activateOnConfigUpdated: activateOnConfigUpdated,
      );
    }
  }
}
