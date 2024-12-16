import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'sentry_js_binding.dart';

SentryJsBinding createJsBinding() {
  return WebSentryJsBinding();
}

class WebSentryJsBinding implements SentryJsBinding {
  @override
  void init(Map<String, dynamic> options) {
    _init(options.jsify());
  }

  @override
  void close() {
    _close();
    if (globalThis['Sentry'] != null) {
      globalThis['Sentry'] = null;
    }
  }
}

@JS('Sentry.init')
external void _init(JSAny? options);

@JS('Sentry.close')
external void _close();

@JS('globalThis')
external JSObject get globalThis;
