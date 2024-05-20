import 'dart:async';
import 'package:web/web.dart' as web;

import 'connectivity_provider.dart';

ConnectivityProvider connectivityProvider() {
  return WebConnectivityProvider();
}

class WebConnectivityProvider implements ConnectivityProvider {
  StreamSubscription<web.Event>? _onOnlineSub;
  StreamSubscription<web.Event>? _onOfflineSub;

  @override
  void listen(void Function(String connectivity) onChange) {
    _onOnlineSub = web.EventStreamProviders.onlineEvent
        .forElement(web.document.body!)
        .listen((_) {
      onChange('wifi');
    });
    _onOfflineSub = web.EventStreamProviders.offlineEvent
        .forElement(web.document.body!)
        .listen((_) {
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
