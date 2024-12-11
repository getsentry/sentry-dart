import 'dart:js_interop';

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
  }
}

@JS('Sentry.init')
external void _init(JSAny? options);

@JS('Sentry.close')
external void _close();
