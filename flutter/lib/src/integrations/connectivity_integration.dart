import 'dart:async';
import 'dart:html' as html;

import 'package:meta/meta.dart';
import '../../sentry_flutter.dart';

class ConnectivityIntegration extends Integration<SentryFlutterOptions> {
  Hub? _hub;
  html.NetworkInformation? _networkInformation;
  String? _oldResult = 'none';

  StreamSubscription<html.Event>? _networkInfoSub;
  StreamSubscription<html.Event>? _onOnlineSub;
  StreamSubscription<html.Event>? _onOfflineSub;

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    _hub = hub;

    final supportsNetworkInformation = html.window.navigator.connection != null;
    if (supportsNetworkInformation) {
      _networkInformation = html.window.navigator.connection;
      _oldResult = _networkInformation?.toConnectivityResult();

      _networkInfoSub = _networkInformation?.onChange.listen((_) {
        final newResult = _networkInformation?.toConnectivityResult();
        if (newResult != null && _oldResult != newResult) {
          _oldResult = newResult;
          addBreadcrumb(newResult);
        }
      });
    } else {
      // Fallback to onLine/onOffline API
      _oldResult = (html.window.navigator.onLine ?? false) ? 'wifi' : 'none';
      _onOnlineSub = html.window.onOnline.listen((_) {
        addBreadcrumb('wifi');
      });
      _onOfflineSub = html.window.onOffline.listen((_) {
        addBreadcrumb('none');
      });
    }
    options.sdk.addIntegration('connectivityIntegration');
  }

  @override
  void close() {
    _hub = null;

    _networkInfoSub?.cancel();
    _networkInfoSub = null;

    _onOnlineSub?.cancel();
    _onOnlineSub = null;

    _onOfflineSub?.cancel();
    _onOfflineSub = null;

    _oldResult = 'none';
    _networkInformation = null;
  }

  @internal
  @visibleForTesting
  void addBreadcrumb(String result) {
    _hub?.addBreadcrumb(
      Breadcrumb(
          category: 'device.connectivity',
          level: SentryLevel.info,
          type: 'connectivity',
          data: {'connectivity': result}),
    );
  }
}

// Source: https://github.com/fluttercommunity/plus_plugins/blob/258f7b8b461f6d78028354f95d24014b240a80f0/packages/connectivity_plus/connectivity_plus/lib/src/web/utils/connectivity_result.dart#L8
extension on html.NetworkInformation {
  String toConnectivityResult() {
    if (downlink == 0 && rtt == 0) {
      return 'none';
    }
    if (type != null) {
      switch (type) {
        case 'none':
          return 'none';
        case 'bluetooth':
          return 'bluetooth';
        case 'cellular':
        case 'mixed':
        case 'other':
        case 'unknown':
          return 'mobile';
        case 'ethernet':
          return 'ethernet';
        default:
          return 'wifi';
      }
    }
    if (effectiveType != null) {
      switch (effectiveType) {
        case 'slow-2g':
        case '2g':
        case '3g':
        case '4g':
          return 'mobile';
        default:
          return 'wifi';
      }
    }
    return 'none';
  }
}
