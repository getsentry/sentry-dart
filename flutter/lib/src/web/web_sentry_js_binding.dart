import 'dart:js_interop';

import 'sentry_js_binding.dart';

SentryJsBinding createJsBinding() {
  return WebSentryJsBinding();
}

class WebSentryJsBinding implements SentryJsBinding {
  @override
  void init(Map<String, dynamic> options) {
    _sentryInit(options.jsify());
  }
}

@JS('Sentry.init')
external void _sentryInit(JSAny? options);
