import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:sentry/sentry.dart';

class SentryFirebaseIntegration extends Integration<SentryOptions> {
  SentryFirebaseIntegration(this._firebaseRemoteConfig, this._keys);

  final FirebaseRemoteConfig _firebaseRemoteConfig;
  final Set<String> _keys;

  StreamSubscription<RemoteConfigUpdate>? _subscription;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) async {
    if (_keys.isEmpty) {
      // TODO: log warning
      return;
    }
    _subscription = _firebaseRemoteConfig.onConfigUpdated.listen((event) async {
      for (final updatedKey in event.updatedKeys) {
        if (_keys.contains(updatedKey)) {
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
