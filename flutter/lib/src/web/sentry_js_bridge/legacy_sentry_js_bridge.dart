import 'dart:js';

import 'sentry_js_bridge.dart';

SentryJsBridge createSentryJsBridge() {
  return LegacySentryJsBridge();
}

class LegacySentryJsBridge implements SentryJsBridge {
  LegacySentryJsBridge({JsObject? sentry})
      : _sentry = sentry ?? context['Sentry'] as JsObject;

  final JsObject _sentry;

  @override
  void init(Map<String, dynamic> options) {
    _sentry.callMethod('init', [JsObject.jsify(options)]);
  }
}
