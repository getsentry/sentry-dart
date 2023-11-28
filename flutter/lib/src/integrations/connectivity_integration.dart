import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:meta/meta.dart';
import '../../sentry_flutter.dart';

class ConnectivityIntegration extends Integration<SentryFlutterOptions> {
  Connectivity connectivity = Connectivity();
  Hub? _hub;
  StreamSubscription<ConnectivityResult>? _subscription;

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    _hub = hub;
    _subscription = connectivity.onConnectivityChanged.listen(addBreadcrumb);

    options.sdk.addIntegration('connectivityIntegration');
  }

  @override
  void close() {
    _hub = null;
    _subscription?.cancel();
    _subscription = null;
  }

  @internal
  @visibleForTesting
  void addBreadcrumb(ConnectivityResult result) {
    _hub?.addBreadcrumb(
      Breadcrumb(
          category: 'device.connectivity',
          level: SentryLevel.info,
          type: 'connectivity',
          data: {'connectivity': result.toSentryConnectivity()}),
    );
  }
}

extension on ConnectivityResult {
  String toSentryConnectivity() {
    switch (this) {
      case ConnectivityResult.bluetooth:
      case ConnectivityResult.vpn:
      case ConnectivityResult.wifi:
        return 'wifi';
      case ConnectivityResult.ethernet:
        return 'ethernet';
      case ConnectivityResult.mobile:
        return 'cellular';
      case ConnectivityResult.none:
        return 'none';
      case ConnectivityResult.other:
        return 'other';
    }
  }
}
