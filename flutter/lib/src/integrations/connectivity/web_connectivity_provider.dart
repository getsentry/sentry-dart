import 'dart:async';
import 'dart:html' as html;

import 'connectivity_provider.dart';

ConnectivityProvider connectivityProvider() {
  return WebConnectivityProvider();
}

class WebConnectivityProvider implements ConnectivityProvider {

  html.NetworkInformation? _networkInformation;
  String? _oldResult;

  StreamSubscription<html.Event>? _networkInfoSub;
  StreamSubscription<html.Event>? _onOnlineSub;
  StreamSubscription<html.Event>? _onOfflineSub;

  @override
  void listen(void Function(String connectivity) onChange) {
    final supportsNetworkInformation = html.window.navigator.connection != null;
    if (supportsNetworkInformation) {
      _networkInformation = html.window.navigator.connection;
      _oldResult = _networkInformation?.toConnectivityResult();

      _networkInfoSub = _networkInformation?.onChange.listen((_) {
        final newResult = _networkInformation?.toConnectivityResult();
        if (newResult != null && _oldResult != newResult) {
          _oldResult = newResult;
          onChange(newResult);
        }
      });
    } else {
      // Fallback to onLine/onOffline API
      _oldResult = (html.window.navigator.onLine ?? false) ? 'wifi' : 'none';
      _onOnlineSub = html.window.onOnline.listen((_) {
        onChange('wifi');
      });
      _onOfflineSub = html.window.onOffline.listen((_) {
        onChange('none');
      });
    }
  }

  @override
  void cancel() {
    _networkInfoSub?.cancel();
    _networkInfoSub = null;

    _onOnlineSub?.cancel();
    _onOnlineSub = null;

    _onOfflineSub?.cancel();
    _onOfflineSub = null;

    _oldResult = null;
    _networkInformation = null;
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
