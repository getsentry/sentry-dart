import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'sentry_js_bridge.dart';

SentryJsBridge createJsApi() {
  return ModernSentryJsBridge();
}

// todo: name tbd
class ModernSentryJsBridge implements SentryJsBridge {
  ModernSentryJsBridge({JSObject? sentry})
      : _sentry = sentry ?? globalContext.getProperty('Sentry'.toJS);

  final JSObject _sentry;

  @override
  void init(Map<String, dynamic> options) {
    _sentry.callMethod('init'.toJS, options.jsify());
  }
}
