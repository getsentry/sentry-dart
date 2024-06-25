import 'dart:async';
import 'dart:html' as html;

import 'connectivity_provider.dart';

ConnectivityProvider connectivityProvider() {
  return WebConnectivityProvider();
}

class WebConnectivityProvider implements ConnectivityProvider {
  StreamSubscription<html.Event>? _onOnlineSub;
  StreamSubscription<html.Event>? _onOfflineSub;

  @override
  void listen(void Function(String connectivity) onChange) {
    _onOnlineSub = html.window.onOnline.listen((_) {
      onChange('wifi');
    });
    _onOfflineSub = html.window.onOffline.listen((_) {
      onChange('none');
    });
  }

  @override
  void cancel() {
    _onOnlineSub?.cancel();
    _onOnlineSub = null;

    _onOfflineSub?.cancel();
    _onOfflineSub = null;
  }
}
