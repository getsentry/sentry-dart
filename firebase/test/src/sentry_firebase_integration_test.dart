import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_firebase/src/sentry_firebase_integration.dart';
import 'package:sentry/sentry.dart';

import 'package:mockito/mockito.dart';
import '../mocks/mocks.mocks.dart';

import 'package:firebase_remote_config/firebase_remote_config.dart';

void main() {

  late final Fixture fixture;

  givenRemoveConfigUpdate(RemoteConfigUpdate update) {
    when(fixture.mockFirebaseRemoteConfig.onConfigUpdated).thenAnswer((_) => Stream.value(update));
  }

  setUp(() {
    fixture = Fixture();

    final update = RemoteConfigUpdate({'test'});
    givenRemoveConfigUpdate(update);
  });

  test('adds integration to options', () {
    final sut = fixture.getSut();
    sut.call(fixture.mockHub, fixture.options);

    expect(fixture.options.sdk.integrations.contains("sentryFirebaseIntegration"), isTrue);
  });  
}

class Fixture {
  
  final mockHub = MockHub();
  final options = SentryOptions(
    dsn: 'https://example.com/sentry-dsn',
  );

  final mockFirebaseRemoteConfig = MockFirebaseRemoteConfig();
  
  SentryFirebaseIntegration getSut() {
    return SentryFirebaseIntegration(mockFirebaseRemoteConfig);
  }
  
}
