import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:sentry/sentry.dart';

class SentryFirebaseIntegration extends Integration<SentryOptions> {
  SentryFirebaseIntegration({
    required FirebaseRemoteConfig firebaseRemoteConfig,
    required Set<String> featureFlagKeys,
    bool activateOnConfigUpdated = true,
  })  : _firebaseRemoteConfig = firebaseRemoteConfig,
        _featureFlagKeys = featureFlagKeys,
        _activateOnConfigUpdated = activateOnConfigUpdated;

  final FirebaseRemoteConfig _firebaseRemoteConfig;
  final Set<String> _featureFlagKeys;
  final bool _activateOnConfigUpdated;
  StreamSubscription<RemoteConfigUpdate>? _subscription;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) async {
    if (_featureFlagKeys.isEmpty) {
      options.logger(
        SentryLevel.warning,
        'No keys provided to $SentryFirebaseIntegration. Will not track feature flags.',
      );
      return;
    }
    _subscription = _firebaseRemoteConfig.onConfigUpdated.listen((event) async {
      if (_activateOnConfigUpdated) {
        await _firebaseRemoteConfig.activate();
      }
      for (final updatedKey in event.updatedKeys) {
        if (_featureFlagKeys.contains(updatedKey)) {
          final value = _firebaseRemoteConfig.getBool(updatedKey);
          await Sentry.addFeatureFlag(updatedKey, value);
        }
      }
    });
    options.sdk.addIntegration('sentryFirebaseIntegration');
  }

  @override
  FutureOr<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
