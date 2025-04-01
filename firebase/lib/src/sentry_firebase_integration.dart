import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:sentry/sentry.dart';

class SentryFirebaseIntegration extends Integration<SentryOptions> {
  SentryFirebaseIntegration(this._firebaseRemoteConfig);

  final FirebaseRemoteConfig _firebaseRemoteConfig;

  StreamSubscription? _subscription;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {
    _subscription = _firebaseRemoteConfig.onConfigUpdated.listen((event) {
      print(event);
    });
    options.sdk.addIntegration('sentryFirebaseIntegration');
  }

  @override
  FutureOr<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
  }  
}
