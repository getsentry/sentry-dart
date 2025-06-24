import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:sentry/sentry.dart';

class SentryFirebaseRemoteConfigIntegration extends Integration<SentryOptions> {
  SentryFirebaseRemoteConfigIntegration({
    required FirebaseRemoteConfig firebaseRemoteConfig,
    bool activateOnConfigUpdated = true,
  })  : _firebaseRemoteConfig = firebaseRemoteConfig,
        _activateOnConfigUpdated = activateOnConfigUpdated;

  final FirebaseRemoteConfig _firebaseRemoteConfig;
  final bool _activateOnConfigUpdated;
  StreamSubscription<RemoteConfigUpdate>? _subscription;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) async {
    for (final key in _firebaseRemoteConfig.getAll().keys) {
      final value = _firebaseRemoteConfig.getBoolOrNull(key);
      if (value != null) {
        unawaited(Sentry.addFeatureFlag(key, value));
      }
    }

    _subscription = _firebaseRemoteConfig.onConfigUpdated.listen((event) async {
      if (_activateOnConfigUpdated) {
        await _firebaseRemoteConfig.activate();
      }
      for (final updatedKey in event.updatedKeys) {
        final value = _firebaseRemoteConfig.getBoolOrNull(updatedKey);
        if (value != null) {
          await Sentry.addFeatureFlag(updatedKey, value);
        }
      }
    });
    options.sdk.addIntegration('SentryFirebaseRemoteConfigIntegration');
  }

  @override
  FutureOr<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}

extension _SentryFirebaseRemoteConfig on FirebaseRemoteConfig {
  bool? getBoolOrNull(String key) {
    final strValue = getString(key);
    final lowerCase = strValue.toLowerCase();
    if (lowerCase == 'true' || lowerCase == '1') {
      return true;
    }
    if (lowerCase == 'false' || lowerCase == '0') {
      return false;
    }
    return null;
  }
}
